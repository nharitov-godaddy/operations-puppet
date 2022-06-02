# SPDX-License-Identifier: Apache-2.0
# == Define: profile::aptrepo::wikimedia
# Prove an apt-repository of local or patched Debian
# packages. Packages placed in this repository must
# be licensed in that allows Wikimedia to distribute
# the software. The repository can be access via:
# https://apt.wikimedia.org/wikimedia/
#
#
# [*primary_server*]
#   The primary server defines that server where packages
#   are uploaded and served.
#
# [*secondary_servers*]
#   Defines standby servers. Receive packages via rsync.
#   These are simply standby servers and not in active use,
#   unless failover/switch over is performed.
#
# [*basedir*]
#   Directory where reprepro stores configuration and
#   distribution files.
#
# [*homedir*]
#   Where to store the GPG keys for signing. GPG keys will be
#   stored in .gnupg relative to this path.
#
# [*gpg_user*]
#   Owner of the GPG keys.
#
# [*gpg_pubring*]
#   The GPG public keyring for reprepro to use. Will be passed to secret().
#
# [*gpg_secring*]
#   The GPG secret keyring for reprepro to use. Will be passed to secret().

class profile::aptrepo::wikimedia (
    Stdlib::Fqdn        $primary_server    = lookup('aptrepo_server'),
    Array[Stdlib::Fqdn] $secondary_servers = lookup('aptrepo_servers_failover'),
    Stdlib::Unixpath    $basedir           = lookup('profile::aptrepo::wikimedia::basedir'),
    Stdlib::Unixpath    $homedir           = lookup('profile::aptrepo::wikimedia::homedir'),
    String              $gpg_user          = lookup('profile::aptrepo::wikimedia::gpg_user'),
    Optional[String]    $gpg_pubring       = lookup('profile::aptrepo::wikimedia::gpg_pubring', {'default_value' => undef}),
    Optional[String]    $gpg_secring       = lookup('profile::aptrepo::wikimedia::gpg_secring', {'default_value' => undef}),
){


    class { 'aptrepo::common':
        homedir     => $homedir,
        basedir     => $basedir,
        gpg_user    => $gpg_user,
        gpg_secring => $gpg_secring,
        gpg_pubring => $gpg_pubring,
    }

    # Public repo, servedby nginx
    aptrepo::repo { 'public_apt_repository':
        basedir            => $basedir,
        incomingdir        => 'incoming',
        distributions_file => 'puppet:///modules/aptrepo/distributions-wikimedia',
    }


    class { 'aptrepo::tftp': }
    include ::profile::backup::host

    # The repository data
    backup::set { 'srv-wikimedia': }

    class { 'aptrepo::rsync':
        primary_server    => $primary_server,
        secondary_servers => $secondary_servers,
    }

    if $primary_server == $::fqdn {
        monitoring::service { 'https':
            description   => 'HTTPS',
            check_command => 'check_ssl_http_letsencrypt_ocsp!apt.wikimedia.org',
            notes_url     => 'https://wikitech.wikimedia.org/wiki/APT_repository',
        }
        $motd_ensure = 'absent'
    } else {
        $motd_ensure = 'present'
    }

    motd::script { 'inactive_warning':
        ensure   => $motd_ensure,
        priority => 1,
        content  => template('profile/install_server/inactive.motd.erb'),
    }
}
