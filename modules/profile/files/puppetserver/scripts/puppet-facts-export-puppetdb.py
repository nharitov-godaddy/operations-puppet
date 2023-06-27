#!/usr/bin/python3
# SPDX-License-Identifier: Apache-2.0
import configparser
import os
import shutil
import subprocess
import tempfile
import urllib3
urllib3.disable_warnings(urllib3.exceptions.SubjectAltNameWarning)

from datetime import datetime, timedelta

import requests
import yaml


class PuppetDBApi(object):
    def __init__(self, puppetdb_config_file):
        config = configparser.ConfigParser()
        config.read(puppetdb_config_file)
        # TODO: add support for multiple urls
        self.server_url = config['main']['server_urls'].split(',')[0]
        self._cacert = None

    @property
    def cacert(self):
        if self._cacert is None:
            self._cacert = subprocess.check_output(
                ['puppet', 'config', 'print', '--section', 'master', 'localcacert']
            ).decode().strip()
        return self._cacert

    def url_for(self, endpoint):
        return '{url}/pdb/query/v4/{ep}'.format(url=self.server_url, ep=endpoint)

    def get(self, endpoint):
        # use the localcacert value whichshould be avalible on all machines
        return requests.get(self.url_for(endpoint), verify=self.cacert).json()


def main():
    date_format = '%Y-%m-%d %H:%M:%S.%s +00:00'
    datetime_facts = datetime.utcnow()
    ts = datetime_facts.strftime(date_format)
    exp = (datetime_facts + timedelta(days=365)).strftime(date_format)

    outfile = '/tmp/puppet-facts-export.tar.xz'
    tmpdir = tempfile.mkdtemp(dir='/tmp', prefix='puppetdb-export')
    factsdir = os.path.join(tmpdir, 'yaml', 'facts')
    print("Saving facts to {}".format(factsdir))
    os.makedirs(factsdir)
    conf = os.environ.get('PUPPETDB_CONFIG_FILE', '/etc/puppet/puppetdb.conf')
    pdb = PuppetDBApi(conf)
    for i, node in enumerate(pdb.get('nodes')):
        if node.get('deactivated', True) is not None:
            continue
        nodename = node['certname']
        yaml_data = {}
        facts = pdb.get('nodes/{}/facts'.format(nodename))
        if not facts:
            continue
        for fact in facts:
            yaml_data[fact['name']] = fact['value']
        filename = os.path.join(factsdir, "{}.yaml".format(nodename))
        # Anonymize potentially reserved data
        yaml_data['uniqueid'] = '43434343'
        yaml_data['boardserialnumber'] = '4242'
        yaml_data['boardproductname'] = '424242'
        yaml_data['serialnumber'] = '42424242'
        del yaml_data['trusted']
        with open(filename, 'w') as fh:
            contents = yaml.dump({'name': nodename, 'values': yaml_data,
                                  'timestamp': ts, 'expiration': exp})
            fh.write('--- !ruby/object:Puppet::Node::Facts\n' + contents)
        if i % 25 == 0:
            print('Wrote {} hosts...'.format(i))
    subprocess.check_call(['tar', 'cJvf', outfile, '--directory', tmpdir, 'yaml'])
    print('Facts exported to {}'.format(outfile))
    shutil.rmtree(tmpdir)


if __name__ == '__main__':
    main()
