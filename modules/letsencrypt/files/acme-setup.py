#!/usr/bin/env python
# -*- coding: utf-8 -*-

# acme-setup - ACME setup and challenge-wrapper script
# Copyright 2016 Brandon Black
# Copyright 2016 Wikimedia Foundation, Inc.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ----------------------------------------------------------------------------
# This script must be run as root (!!), and the user 'acme' (or alternative via
# cmdline argument -u) must exist as a unique unprivileged user dedicated to
# the purpose of executing the actual ACME network challenges.  Note this
# relies on an installed copy of 'acme-tiny' as well as our own x509-bundle
# script, puppetized elsewhere in the sslcert module.
#
# If the mode is 'self' (the default), the output certificate file will be
# self-signed; no actual ACME challenges are executed and no network fetches
# happen at all.  The intent of this mode is that it is used to pre-setup the
# outputs such that an HTTP server config can reference the cert/key and start
# successfully with a self-signed cert, so that it can be used to execute the
# real challenge later.
#
# If the mode is 'acme', a real acme HTTP challenge will be executed via
# 'acme-tiny' to generate the cert.  The acme challenge will place challenge
# files at '/var/acme/challenge/' and assume a service is running which can
# answer correctly from that directory.  If '-w' is supplied and a new cert is
# generated, the named web server service will be reloaded via:
# '/usr/sbin/service $w reload'
#
# Regardless of mode, this script always sets up the basic directories and
# key/cert/csr files under /etc/acme and /var/acme if any are missing, and
# fixes any permissions issues on existing ones.  It will overwrite an existing
# csr and/or cert if:
# 1. pre-requisites had to be regenerated (e.g. if tls key was missing)
# 2. subjects list does not match current subjects
# 3. for 'acme' mode, if the existing cert is self-signed
# 4. expiry is near: simple fixed 2 day threshold for self-signed.  For actual
#    ACME certs, the threshold is randomly swizzled with overrideable default
#    constants of 37 days baseline +/- 7 days randomness.  This is to help
#    spread renewals in the case of many certs configured on a single server.
#    The 'random' offset is deterministically derived from the cert's serial
#    so that the check is consistent per-cert when frequently checking expiry.
#
# If you want to periodically rotate the otherwise-persistent account or TLS
# keys, simply delete them just before running this script.
#
# This script normalizes the "subjects" list: it downcases all subjects and
# sorts them in lexographic order before further processing.  The upside is
# this ensures consistency and that we don't pointlessly re-issue LE certs due
# to random ordering changes in the caller's subject list.  The downside is the
# caller can't put a special name as the first subject in the set and expect it
# to work for non-SAN browsers.  One must assume that our LE certs with
# multiple hostnames are not reliably compatible with browsers that don't do
# SAN, for all names.
# ----------------------------------------------------------------------------
#
# The intended integration with calling tools is something like this for the
# easiest cases (normal webserver that can config for challenge):
#
# * for initial setup:
# * set webserver config (nginx/apache/whatever) to include a standard config
#   fragment to map /.well-known/acme-challenge to /var/acme/challenge in
#   addition to whatever normal runtime config it needs, and with TLS config
#   referencing the key/cert to be generated by this script.  These things
#   should be part of its normal runtime config always.
# * execute this script with mode 'self' to generate a self-signed cert (this
#   won't mess up an existing ACME-signed valid cert if you run this all the
#   time as part of cfg mgmt).
# * start the webserver.
# * execute this script again with mode 'acme' to generate a real certificate
#   via acme challenge through the webserver.  Use '-w' to reload the webserver
#   at the end and pick up the new crt/chain if one is generated.
# * for periodic renewal checks, repeat the above.  You can do this as often as
#   you like; the challenge and cert re-creation will only happen after expiry
#   threshold is met (default: 37+/-7 days left).
#
# ----------------------------------------------------------------------------
# -- directory layout generated by this the code:
# /etc/acme/                   - root:root/755
# /etc/acme/acct/              - root:root/711
# /etc/acme/key/               - root:root/711
# /etc/acme/csr/               - root:root/755
# /etc/acme/cert/              - root:root/755
# /var/acme/                   - root:root/755
# /var/acme/challenge/         - acme_user:root/755
# -- global files generated once:
# /etc/acme/acct/acct.key      - acme_user:root/400 # persists indefinitely
# -- files generated when run with id "x":
# /etc/acme/key/x.key          - key_user:key_group/440 # persists indefinitely
#                                    ^ 440 if key_group non-root, 400 otherwise
# /etc/acme/csr/x.pem          - root:root/644 # persists if no subj change
# /etc/acme/cert/x.crt         - root:root/644 # just our signed cert
# /etc/acme/cert/x.chain.crt   - root:root/644 # intermediate (apache)
# /etc/acme/cert/x.chained.crt - root:root/644 # x.crt + intermediate (nginx)
# ----------------------------------------------------------------------------
# Note that while this script is named as if it's generic to any usage of ACME,
# at present it's full of LetsEncrypt assumptions (that account keys are
# mostly-ephemeral, the challenge server addresses, how CSRs are constructed,
# etc), because that's all we're using here.  The intent is to refactor/expand
# this script at a later date when we have a second use-case for e.g. ACME with
# a commercial cert vendor.
# ----------------------------------------------------------------------------

import re
import os
import sys
import pwd
import grp
import stat
import errno
import shutil
import random
import argparse
import tempfile
import datetime
import subprocess

# Constants:
ETC_DIR = '/etc/acme'
VAR_DIR = '/var/acme'
SVC = '/usr/sbin/service'
OSSL = '/usr/bin/openssl'
ATINY = '/usr/local/sbin/acme_tiny.py'
X5B = '/usr/local/sbin/x509-bundle'


def info(str):
    """Saves some code line noise"""

    sys.stderr.write(str + '\n')


def parse_options():
    """Parse command-line options, return args hash"""

    parser = argparse.ArgumentParser(description="ACME Setup")

    parser.add_argument('-i', dest='id', type=str,
                        help='unique cert id on this host, used in filenames',
                        required=True)
    parser.add_argument('-s', dest='subjects', type=lambda s: s.split(','),
                        help='comma-separated list of DNS hostnames',
                        required=True)
    parser.add_argument('-m', dest='mode', type=str,
                        help='mode (def %(default)s)',
                        choices=['self', 'acme'],
                        default='self')
    parser.add_argument('-u', dest='acme_user', type=str,
                        help='unprivileged acme user name (def %(default)s)',
                        default='acme')
    parser.add_argument('-d', dest='exp_days', type=int,
                        help='base expiry threshold in days (def %(default)s)',
                        default=37)
    parser.add_argument('-r', dest='exp_rand', type=int,
                        help='random +/- days for expiry (def %(default)s)',
                        default=7)
    parser.add_argument('-w', dest='svc', type=str,
                        help='reload on new ACME cert (def %(default)s)',
                        default=None)
    parser.add_argument('--key-user', dest='key_user', type=str,
                        help='User owning private key (def %(default)s)',
                        default='root')
    parser.add_argument('--key-group', dest='key_group', type=str,
                        help='Group owning private key (def %(default)s)',
                        default='root')

    return parser.parse_args()


def check_output_errtext(args):
    """exec args, returns (stdout,stderr). raises on rv!=0 w/ stderr in msg"""

    p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (p_out, p_err) = p.communicate()
    if p.returncode != 0:
        raise Exception("Command >>%s<< failed, exit code %i, stderr:\n%s"
                        % (" ".join(args), p.returncode, p_err))
    return (p_out, p_err)


def ensure_real_fs(path, mode, uid, gid, is_dir, creator, forcer):
    """Ensure real file/dir with above params, rv indicates creation"""

    create = False
    try:
        st = os.lstat(path)
    except OSError as exc:
        if exc.errno == errno.ENOENT:
            create = True
        else:
            raise

    if create or forcer():
        creator()
        create = True
        st = os.lstat(path)
    if is_dir:
        if not stat.S_ISDIR(st.st_mode):
            raise Exception('%s is not a directory' % (path))
    else:
        if not stat.S_ISREG(st.st_mode):
            raise Exception('%s is not a regular file' % (path))
    if st.st_uid != uid or st.st_gid != gid:
        os.chown(path, uid, gid)
    if (st.st_mode & 0o777) != mode:
        os.chmod(path, mode)

    return create


def ensure_dir(dir, uid, gid, mode):
    """Ensure dir exists with this mode"""

    def dir_create():
        info('Creating directory ' + dir)
        os.mkdir(dir, mode)

    def dir_force():
        return False

    ensure_real_fs(dir, mode, uid, gid, True, dir_create, dir_force)


def ensure_key(key, uid, gid, mode, bits):
    """Ensure root-owned key w/ correct mode, use bits if creating"""

    def key_create():
        info('Creating Key ' + key)
        check_output_errtext([OSSL, 'genrsa', '-out', key, str(bits)])

    def key_force():
        return False

    return ensure_real_fs(key, mode, uid, gid, False, key_create, key_force)


def parse_ossl_stamp(stamp):
    """Parse an timestamp from OpenSSL output to a datetime object"""

    return datetime.datetime.strptime(stamp, "%b %d %H:%M:%S %Y %Z")


def check_expiry(txt, exp_days, exp_rand):
    """Checks openssl text output for expiry < d+/-r days away"""

    v_pat = r'^\s*Validity\n\s*Not Before: ([^\n]+)\n\s*Not After : ([^\n]+)\n'
    v_res = re.search(v_pat, txt, re.M)
    if not v_res:
        return True
    cert_notbefore = parse_ossl_stamp(v_res.group(1))
    cert_notafter = parse_ossl_stamp(v_res.group(2))

    now = datetime.datetime.utcnow()

    cert_notbefore_max = now + datetime.timedelta(seconds=60)
    if cert_notbefore > cert_notbefore_max:
        return True

    exp_secs = exp_days * 86400
    if exp_rand:
        plusminus = exp_rand * 86400
        s_res = re.search(r'^\s*Serial Number:(.*)$', txt, re.M)
        if not s_res:
            return True
        random.seed(s_res.group(1))
        exp_secs += random.randint(-1 * plusminus, plusminus)
    renew_at = cert_notafter - datetime.timedelta(seconds=exp_secs)
    info('Cert renewal on or after ' + renew_at.isoformat())
    if now >= renew_at:
        return True

    return False


def chk_ossl(file, which, subjects, check_ss, exp_days, exp_rand):
    """Check Cert or CSR text output for various things"""

    try:
        txt = check_output_errtext([OSSL, which, '-in', file, '-text'])[0]
    except Exception:
        return True

    subj_re = r'^\s*Subject:\s*(.*/)?\s*CN\s*=\s*' + re.escape(subjects[0]) + r'(/|\s*$)'
    if not re.search(subj_re, txt, re.M):
        return True

    san_re = (
        r'^\s*X509v3 Subject Alternative Name:\s*'
        + (r',\s*'.join(['DNS:' + re.escape(s) for s in subjects]))
        + r'\s*$'
    )
    if not re.search(san_re, txt, re.M):
        return True

    if check_ss:
        sm = re.search(r'^\s*Subject:\s*(.*)$', txt, re.M)
        im = re.search(r'^\s*Issuer:\s*(.*)$', txt, re.M)
        if not sm or not im or sm.group(1) == im.group(1):
            return True

    if exp_days and check_expiry(txt, exp_days, exp_rand):
        return True

    return False


def ensure_csr(csr, subjects, tls_key, force):
    """Ensure CSR for subjects"""

    def csr_create():
        info('Creating CSR ' + csr)
        with tempfile.NamedTemporaryFile() as cfg:
            cfg.write('\n'.join([
                '[req]',
                'distinguished_name=req_dn',
                'req_extensions=SAN',
                'prompt=no',
                '[req_dn]',
                'commonName=' + subjects[0],
                '[SAN]',
                'subjectAltName=' + ','.join(['DNS:' + s for s in subjects]),
            ]))
            cfg.flush()
            check_output_errtext([
                OSSL, 'req', '-new', '-sha256', '-out', csr, '-key', tls_key,
                '-config', cfg.name
            ])

    def csr_force():
        return force or chk_ossl(csr, 'req', subjects, False, None, 0)

    return ensure_real_fs(csr, 0o644, 0, 0, False, csr_create, csr_force)


def acme_challenge(id, cert_dir, acct_key, csr, chal_dir, acme_user):
    """Execute the ACME challenge, generating a real cert"""

    tls_crt = os.path.join(cert_dir, '%s.crt' % id)
    info('Getting ACME cert ' + tls_crt)

    def privdrop():
        os.chdir('/')
        os.setgid(acme_user.pw_gid)
        os.initgroups(acme_user.pw_name, acme_user.pw_gid)
        os.setuid(acme_user.pw_uid)

    args = [
        ATINY, '--account-key', acct_key, '--csr', csr, '--acme-dir', chal_dir
    ]

    try:
        cert_tmp = tempfile.NamedTemporaryFile(dir=cert_dir, delete=False)
        p = subprocess.Popen(args, stdout=cert_tmp, stderr=subprocess.PIPE,
                             preexec_fn=privdrop)
        (p_out, p_err) = p.communicate()
        if p.returncode != 0:
            raise Exception("Command >>%s<< failed, exit code %i, stderr:\n%s"
                            % (" ".join(args), p.returncode, p_err))
        cert_tmp.flush()
        os.fsync(cert_tmp.fileno())
        cert_tmp.close()
        ctn = cert_tmp.name
        c_chain = os.path.join(cert_dir, '%s.chain.crt' % id)
        c_chained = os.path.join(cert_dir, '%s.chained.crt' % id)
        check_output_errtext([X5B, '-c', ctn, '-o', c_chain, '-s', '-f'])
        check_output_errtext([X5B, '-c', ctn, '-o', c_chained, '-s'])
        os.rename(ctn, tls_crt)
    except Exception:
        try:
            os.unlink(cert_tmp.name)
        except Exception:
            pass
        raise


def ensure_crt_acme(id, cert_dir, acct_key, csr, subjects, exp_days,
                    exp_rand, chal_dir, acme_user, svc, force):
    """Ensure valid cert exists via ACME challenge"""

    tls_crt = os.path.join(cert_dir, '%s.crt' % id)

    def cert_create():
        acme_challenge(id, cert_dir, acct_key, csr, chal_dir, acme_user)
        if svc:
            check_output_errtext([SVC, svc, 'reload'])

    def cert_force():
        return force or chk_ossl(tls_crt, 'x509', subjects, True, exp_days,
                                 exp_rand)

    ensure_real_fs(tls_crt, 0o644, 0, 0, False, cert_create, cert_force)


def ensure_crt_self(id, cert_dir, tls_key, csr, subjects, force):
    """Ensure valid cert exists (self-signed if must create)"""

    tls_crt = os.path.join(cert_dir, '%s.crt' % id)
    c_chain = os.path.join(cert_dir, '%s.chain.crt' % id)
    c_chained = os.path.join(cert_dir, '%s.chained.crt' % id)

    def cert_create():
        info('Creating self-signed cert ' + tls_crt)
        with tempfile.NamedTemporaryFile() as extfile:
            extfile.write('\n'.join([
                '[v3_req]',
                'keyUsage=critical,digitalSignature,keyEncipherment',
                'basicConstraints=CA:FALSE',
                'extendedKeyUsage=serverAuth',
                'subjectAltName=' + ','.join(['DNS:' + s for s in subjects]),
            ]))
            extfile.flush()
            check_output_errtext([
                OSSL, 'x509', '-req', '-sha256', '-out', tls_crt, '-in', csr,
                '-signkey', tls_key, '-extfile', extfile.name, '-extensions',
                'v3_req', '-days', '90'
            ])
            for fn in [c_chain, c_chained]:
                info('Copying ' + tls_crt + ' to ' + fn)
                shutil.copy(tls_crt, fn)
                os.chown(fn, 0, 0)

    def cert_force():
        return force or chk_ossl(tls_crt, 'x509', subjects, False, 2, 0)

    ensure_real_fs(tls_crt, 0o644, 0, 0, False, cert_create, cert_force)


def acme_setup(id, subjects, mode, exp_days, exp_rand, acme_user, svc,
               key_uid, key_gid):
    """Do all the things this script does"""

    # Directory structure
    acct_dir = os.path.join(ETC_DIR, 'acct')
    key_dir = os.path.join(ETC_DIR, 'key')
    csr_dir = os.path.join(ETC_DIR, 'csr')
    cert_dir = os.path.join(ETC_DIR, 'cert')
    chal_dir = os.path.join(VAR_DIR, 'challenge')
    ensure_dir(ETC_DIR,  0, 0, 0o755)
    ensure_dir(acct_dir, 0, 0, 0o711)
    ensure_dir(key_dir,  0, 0, 0o711)
    ensure_dir(csr_dir,  0, 0, 0o755)
    ensure_dir(cert_dir, 0, 0, 0o755)
    ensure_dir(VAR_DIR,  0, 0, 0o755)
    ensure_dir(chal_dir, acme_user.pw_uid, 0, 0o755)

    # Keys
    os.umask(0o077)
    acct_key = os.path.join(acct_dir, 'acct.key')
    ensure_key(acct_key, acme_user.pw_uid, 0, 0o400, 4096)
    tls_key = os.path.join(key_dir, '%s.key' % id)
    if key_gid != 0:
        key_mode = 0o440
    else:
        key_mode = 0o400
    force_csr = ensure_key(tls_key, key_uid, key_gid, key_mode, 2048)
    os.umask(0o022)

    # CSR based on tls_key + subjects
    csr = os.path.join(csr_dir, '%s.pem' % id)
    force_crt = ensure_csr(csr, subjects, tls_key, force_csr)

    if mode == 'self':
        ensure_crt_self(id, cert_dir, tls_key, csr, subjects, force_crt)
    else:
        ensure_crt_acme(id, cert_dir, acct_key, csr, subjects, exp_days,
                        exp_rand, chal_dir, acme_user, svc, force_crt)


def main():
    """Basic pre-setup: CLI parse, sanity-checks, etc"""

    os.umask(0o022)
    args = parse_options()
    if os.geteuid() != 0 or os.getegid() != 0:
        raise Exception('This script must run as root')
    if args.exp_rand * 2 >= args.exp_days:
        raise Exception('-r %s must be less than half of -d %s'
                        % (args.exp_rand, args.exp_days))

    reg_id = re.compile('^[-a-zA-Z0-9_]+$')
    if not reg_id.match(args.id):
        raise Exception('-i must match ^[-a-zA-Z0-9_]+$ ')

    acme_user = pwd.getpwnam(args.acme_user)
    key_uid = pwd.getpwnam(args.key_user).pw_uid
    key_gid = grp.getgrnam(args.key_group).gr_gid

    subjects = list(set([item.lower() for item in args.subjects]))
    subjects.sort()

    acme_setup(args.id, subjects, args.mode,
               args.exp_days, args.exp_rand, acme_user, args.svc,
               key_uid, key_gid)


if __name__ == '__main__':
    main()

# vim: set ts=4 sw=4 et:
