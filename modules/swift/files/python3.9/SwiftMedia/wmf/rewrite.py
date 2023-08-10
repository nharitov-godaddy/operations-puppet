# SPDX-License-Identifier: Apache-2.0
# Portions Copyright (c) 2010 OpenStack, LLC.
# Everything else Copyright (c) 2011 Wikimedia Foundation, Inc.
# all of it licensed under the Apache Software License, included by reference.

# Tests are in rewrite_integration_test.py.

import re
import urllib.parse

from swift.common import swob
from swift.common.utils import get_logger
from swift.common.wsgi import WSGIContext


class DumbRedirectHandler(urllib.request.HTTPRedirectHandler):

    def http_error_301(self, req, fp, code, msg, headers):
        return None

    def http_error_302(self, req, fp, code, msg, headers):
        return None


class _WMFRewriteContext(WSGIContext):
    """
    Rewrite Media Store URLs so that swift knows how to deal with them.
    """

    def __init__(self, rewrite, conf):
        WSGIContext.__init__(self, rewrite.app)
        self.app = rewrite.app
        self.logger = rewrite.logger

        self.account = conf['account'].strip()
        self.thumborhost = conf['thumborhost'].strip()
        self.user_agent = conf['user_agent'].strip()
        self.bind_port = conf['bind_port'].strip()
        self.shard_container_list = [
            item.strip() for item in conf['shard_container_list'].split(',')]

    def thumborify_url(self, reqorig, host):
        reqorig.host = host
        thumbor_urlobj = list(urllib.parse.urlsplit(reqorig.url))
        thumbor_urlobj[2] = urllib.parse.quote(thumbor_urlobj[2], '%/')
        return urllib.parse.urlunsplit(thumbor_urlobj)

    def handle404(self, reqorig, url, container, obj):
        """
        Return a swob.Response which fetches the thumbnail from the thumb
        host and returns it. Note also that the thumb host might write it out
        to Swift so it won't 404 next time.
        """
        # upload doesn't like our User-agent, otherwise we could call it
        # using urllib2.url()
        thumbor_opener = urllib.request.build_opener(DumbRedirectHandler())

        # Pass on certain headers from Varnish to Thumbor
        thumbor_opener.addheaders = []
        if reqorig.headers.get('User-Agent') is not None:
            thumbor_opener.addheaders.append(('User-Agent', reqorig.headers.get('User-Agent')))
        else:
            thumbor_opener.addheaders.append(('User-Agent', self.user_agent))
        for header_to_pass in ['X-Forwarded-For', 'X-Forwarded-Proto',
                               'Accept', 'Accept-Encoding', 'X-Original-URI', 'X-Client-IP']:
            if reqorig.headers.get(header_to_pass) is not None:
                header = (header_to_pass, reqorig.headers.get(header_to_pass))
                thumbor_opener.addheaders.append(header)

        # At least in theory, we shouldn't be handing out links to originals
        # that we don't have (or in the case of thumbs, can't generate).
        # However, someone may have a formerly valid link to a file, so we
        # should do them the favor of giving them a 404.
        try:
            thumbor_encodedurl = self.thumborify_url(reqorig, self.thumborhost)
            upcopy = thumbor_opener.open(thumbor_encodedurl)
        except urllib.error.HTTPError as error:
            # Wrap the urllib2 HTTPError into a swob HTTPException
            status = error.code
            body = error.fp.read()
            headers = list(error.hdrs.items())
            if status not in swob.RESPONSE_REASONS:
                # Generic status description in case of unknown status reasons.
                status = "%s Error" % status
            return swob.HTTPException(status=status, body=body, headers=headers)
        except urllib.error.URLError as error:
            msg = 'There was a problem while contacting the thumbnailing service: %s' % \
                  error.reason
            return swob.HTTPServiceUnavailable(msg)

        # get the Content-Type.
        uinfo = upcopy.info()
        c_t = uinfo.get_content_type()

        resp = swob.Response(app_iter=upcopy, content_type=c_t)

        headers_whitelist = [
            'Content-Length',
            'Content-Disposition',
            'Last-Modified',
            'Accept-Ranges',
            'XKey',
            'Thumbor-Engine',
            'Server',
            'Nginx-Request-Date',
            'Nginx-Response-Date',
            'Thumbor-Processing-Time',
            'Thumbor-Processing-Utime',
            'Thumbor-Request-Id',
            'Thumbor-Request-Date'
        ]

        # add in the headers if we've got them
        for header in headers_whitelist:
            if uinfo.get(header) is not None:
                resp.headers[header] = uinfo.get(header)

        # also add CORS; see also our CORS middleware
        resp.headers['Access-Control-Allow-Origin'] = '*'

        return resp

    def handle_request(self, env, start_response):
        try:
            return self._handle_request(env, start_response)
        except UnicodeDecodeError:
            self.logger.exception('Failed to decode request %r', env)
            resp = swob.HTTPBadRequest('Failed to decode request')
            return resp(env, start_response)

    def _handle_request(self, env, start_response):
        # In python3, we have to care about bytes vs strings
        # req.path_info is url-encoded ASCII
        # req.path is the byte stream resulting from url-decoding path_info
        # turned into a string using the latin1 encoding (even though mw
        # uses utf-8); essentially req.path contains "mojibake" and if we
        # need to manipulate it, we have to re-decode-and-encode back into
        # utf-8.
        # Similarly, when setting path_info, we have to be sure to set
        # it to either a byte sequence of valid utf-8 codepoints, or a
        # latin1 encoding of the desired byte sequence.

        req = swob.Request(env)

        # If the client has sent us URL-encoded invalid utf-8, then say
        # 400 immediately and don't log a backtrace
        try:
            urllib.parse.unquote(req.path, errors="strict")
        except UnicodeDecodeError:
            resp = swob.HTTPBadRequest('Failed to decode request')
            return resp(env, start_response)

        # Double (or triple, etc.) slashes in the URL should be ignored;
        # collapse them. fixes T34864
        # mojibake-safe since 0x2F is / in all relevant encodings
        req.path_info = re.sub(r'/{2,}', '/', req.path_info)

        # Keep a copy of the original request so we can ask the scalers for it
        reqorig = swob.Request(req.environ.copy())

        # Containers have 5 components: project, language, repo, zone, and shard.
        # If there's no zone in the URL, the zone is assumed to be 'public' (for b/c).
        # Shard is optional (and configurable), and is only used for large containers.
        #
        # Projects are wikipedia, wikinews, etc.
        # Languages are en, de, fr, commons, etc.
        # Repos are local, timeline, etc.
        # Zones are public, thumb, temp, etc.
        # Shard is extracted from "hash paths" in the URL and is 2 hex digits.
        #
        # These attributes are mapped to container names in the form of either:
        # (a) proj-lang-repo-zone (if not sharded)
        # (b) proj-lang-repo-zone.shard (if sharded)
        # (c) global-data-repo-zone (if not sharded)
        # (d) global-data-repo-zone.shard (if sharded)
        #
        # Rewrite wiki-global URLs of these forms:
        # (a) http://upload.wikimedia.org/math/<relpath>
        #         => http://msfe/v1/AUTH_<hash>/global-data-math-render/<relpath>
        # (b) http://upload.wikimedia.org/<proj>/<lang>/math/<relpath> (legacy)
        #         => http://msfe/v1/AUTH_<hash>/global-data-math-render/<relpath>
        #
        # Rewrite wiki-relative URLs of these forms:
        # (a) http://upload.wikimedia.org/<proj>/<lang>/<relpath>
        #         => http://msfe/v1/AUTH_<hash>/<proj>-<lang>-local-public/<relpath>
        # (b) http://upload.wikimedia.org/<proj>/<lang>/archive/<relpath>
        #         => http://msfe/v1/AUTH_<hash>/<proj>-<lang>-local-public/archive/<relpath>
        # (c) http://upload.wikimedia.org/<proj>/<lang>/thumb/<relpath>
        #         => http://msfe/v1/AUTH_<hash>/<proj>-<lang>-local-thumb/<relpath>
        # (d) http://upload.wikimedia.org/<proj>/<lang>/thumb/archive/<relpath>
        #         => http://msfe/v1/AUTH_<hash>/<proj>-<lang>-local-thumb/archive/<relpath>
        # (e) http://upload.wikimedia.org/<proj>/<lang>/thumb/temp/<relpath>
        #         => http://msfe/v1/AUTH_<hash>/<proj>-<lang>-local-thumb/temp/<relpath>
        # (f) http://upload.wikimedia.org/<proj>/<lang>/transcoded/<relpath>
        #         => http://msfe/v1/AUTH_<hash>/<proj>-<lang>-local-transcoded/<relpath>
        # (g) http://upload.wikimedia.org/<proj>/<lang>/timeline/<relpath>
        #         => http://msfe/v1/AUTH_<hash>/<proj>-<lang>-timeline-render/<relpath>

        # regular uploads
        match = re.match(
            (r'^/(?P<proj>[^/]+)/(?P<lang>[^/]+)/'
             r'((?P<zone>transcoded|thumb)/)?'
             r'(?P<path>((temp|archive)/)?[0-9a-f]/(?P<shard>[0-9a-f]{2})/.+)$'),
            req.path)
        if match:
            proj = match.group('proj')
            lang = match.group('lang')
            repo = 'local'  # the upload repo name is "local"
            # Get the repo zone (if not provided that means "public")
            zone = (match.group('zone') if match.group('zone') else 'public')
            # Get the object path relative to the zone (and thus container)
            obj = match.group('path')  # e.g. "archive/a/ab/..."
            shard = match.group('shard')

        # timeline renderings
        if match is None:
            # /wikipedia/en/timeline/a876297c277d80dfd826e1f23dbfea3f.png
            match = re.match(
                r'^/(?P<proj>[^/]+)/(?P<lang>[^/]+)/(?P<repo>timeline)/(?P<path>.+)$',
                req.path)
            if match:
                proj = match.group('proj')  # wikipedia
                lang = match.group('lang')  # en
                repo = match.group('repo')  # timeline
                zone = 'render'
                obj = match.group('path')  # a876297c277d80dfd826e1f23dbfea3f.png
                shard = ''

        # math renderings
        if match is None:
            # /math/c/9/f/c9f2055dadfb49853eff822a453d9ceb.png
            # /wikipedia/en/math/c/9/f/c9f2055dadfb49853eff822a453d9ceb.png (legacy)
            match = re.match(
                (r'^(/(?P<proj>[^/]+)/(?P<lang>[^/]+))?/(?P<repo>math)/'
                 r'(?P<path>(?P<shard1>[0-9a-f])/(?P<shard2>[0-9a-f])/.+)$'),
                req.path)

            if match:
                proj = 'global'
                lang = 'data'
                repo = match.group('repo')  # math
                zone = 'render'
                obj = match.group('path')  # c/9/f/c9f2055dadfb49853eff822a453d9ceb.png
                shard = match.group('shard1') + match.group('shard2')  # c9

        # score renderings
        if match is None:
            # /score/j/q/jqn99bwy8777srpv45hxjoiu24f0636/jqn99bwy.png
            # /score/override-midi/8/i/8i9pzt87wtpy45lpz1rox8wusjkt7ki.ogg
            match = re.match(r'^/(?P<repo>score)/(?P<path>.+)$', req.path)
            if match:
                proj = 'global'
                lang = 'data'
                repo = match.group('repo')  # score
                zone = 'render'
                obj = match.group('path')  # j/q/jqn99bwy8777srpv45hxjoiu24f0636/jqn99bwy.png
                shard = ''

        # phonos renderings
        if match is None:
            # /phonos/0/h/0hp7eif2wwbuhif94n42bzm95o71z9i.mp3
            match = re.match(r'^/(?P<repo>phonos)/(?P<path>.+)$', req.path)
            if match:
                proj = 'global'
                lang = 'data'
                repo = match.group('repo')  # phonos
                zone = 'render'
                obj = match.group('path')  # 0/h/0hp7eif2wwbuhif94n42bzm95o71z9i.mp3
                shard = ''

        if match is None:
            match = re.match(r'^/monitoring/(?P<what>.+)$', req.path)
            if match:
                what = match.group('what')
                if what == 'frontend':
                    headers = {'Content-Type': 'application/octet-stream'}
                    resp = swob.Response(headers=headers, body="OK\n")
                elif what == 'backend':
                    req.host = '127.0.0.1:%s' % self.bind_port
                    req.path_info = "/v1/%s/monitoring/backend" % self.account

                    app_iter = self._app_call(env)
                    status = self._get_status_int()
                    headers = self._response_headers

                    resp = swob.Response(status=status, headers=headers, app_iter=app_iter)
                else:
                    resp = swob.HTTPNotFound('Monitoring type not found "%s"' % (req.path))
                return resp(env, start_response)

        if match is None:
            match = re.match(r'^/(?P<path>[^/]+)?$', req.path)
            # /index.html /favicon.ico /robots.txt etc.
            # serve from a default "root" container
            if match:
                path = match.group('path')
                if not path:
                    path = 'index.html'

                req.host = '127.0.0.1:%s' % self.bind_port
                req.path_info = "/v1/%s/root/%s" % (self.account, path)

                app_iter = self._app_call(env)
                status = self._get_status_int()
                headers = self._response_headers

                resp = swob.Response(status=status, headers=headers, app_iter=app_iter)
                return resp(env, start_response)

        # Internally rewrite the URL based on the regex it matched...
        if match:
            # Get the per-project "conceptual" container name, e.g. "<proj><lang><repo><zone>"
            container = "%s-%s-%s-%s" % (proj, lang, repo, zone)
            # Add 2-digit shard to the container if it is supposed to be sharded.
            # We may thus have an "actual" container name like "<proj><lang><repo><zone>.<shard>"
            if container in self.shard_container_list:
                container += ".%s" % shard

            # Save a url with just the account name in it.
            req.path_info = "/v1/%s" % (self.account)
            port = self.bind_port
            req.host = '127.0.0.1:%s' % port
            url = req.url[:]
            # Create a path to our object's name.
            # Make the correct unicode string we want
            newpath = "/v1/%s/%s/%s" % (self.account, container,
                                        urllib.parse.unquote(obj,
                                                             errors='strict'))
            # Then encode to a byte sequence using utf-8
            req.path_info = newpath.encode('utf-8')
            # self.logger.warn("new path is %s" % req.path_info)

            # do_start_response just remembers what it got called with,
            # because our 404 handler will generate a different response.
            app_iter = self._app_call(env)
            status = self._get_status_int()
            headers = self._response_headers

            if status == 404:
                # only send thumbs to the 404 handler; just return a 404 for everything else.
                if repo == 'local' and zone == 'thumb':
                    resp = self.handle404(reqorig, url, container, obj)
                    return resp(env, start_response)
                else:
                    resp = swob.HTTPNotFound('File not found: %s' % req.path)
                    return resp(env, start_response)
            else:
                # Return the response verbatim
                return swob.Response(status=status, headers=headers,
                                     app_iter=app_iter)(env, start_response)
        else:
            resp = swob.HTTPNotFound('Regexp failed to match URI: "%s"' % (req.path))
            return resp(env, start_response)


class WMFRewrite(object):

    def __init__(self, app, conf):
        self.app = app
        self.conf = conf
        self.logger = get_logger(conf)

    def __call__(self, env, start_response):
        # end-users should only do GET/HEAD, nothing else needs a rewrite
        if env['REQUEST_METHOD'] not in ('HEAD', 'GET'):
            return self.app(env, start_response)

        # do nothing on authenticated and authentication requests
        path = env['PATH_INFO']
        if path.startswith('/auth') or path.startswith('/v1/AUTH_'):
            return self.app(env, start_response)

        context = _WMFRewriteContext(self, self.conf)
        return context.handle_request(env, start_response)


def filter_factory(global_conf, **local_conf):
    conf = global_conf.copy()
    conf.update(local_conf)

    def wmfrewrite_filter(app):
        return WMFRewrite(app, conf)

    return wmfrewrite_filter

# vim: set expandtab tabstop=4 shiftwidth=4 autoindent:
