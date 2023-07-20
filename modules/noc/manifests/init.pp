# SPDX-License-Identifier: Apache-2.0
# https://noc.wikimedia.org/
class noc {

    # NOC needs a working mediawiki installation at the moment
    # so it will need profile::mediawiki::common to be present.

    httpd::conf { 'define_HHVM':
        conf_type => 'env',
        content   => "export APACHE_ARGUMENTS=\"\$APACHE_ARGUMENTS -D HHVM\"",
    }

    include ::noc::php_engine

    ensure_packages('libapache2-mod-php')

    httpd::site { 'noc.wikimedia.org':
        content => template('noc/noc.wikimedia.org.erb'),
    }

    # TODO: remove after absenting
    $fetch_dbconfig_user = 'mwdeploy'
    file { '/srv/dbconfig':
        ensure => absent,
        owner  => $fetch_dbconfig_user,
        group  => $fetch_dbconfig_user,
        mode   => '0755',
    }
    file { '/srv/dbconfig/README':
        ensure  => absent,
        content => join(
            [
                'Database configs mirrored from etcd.',
                'This directory is publicly viewable on the web.'],
            '\n'),
        require => File['/srv/dbconfig'],
    }

    $fetch_dbconfig_path = '/usr/local/sbin/fetch_dbconfig'

    file { $fetch_dbconfig_path:
        ensure => absent,
        source => 'puppet:///modules/noc/fetch_dbconfig.sh',
        mode   => '0755',
    }

    systemd::timer::job { 'fetch_dbconfig':
        ensure          => absent,
        description     => 'Fetch the dbconfig from etcd and store it locally',
        command         => $fetch_dbconfig_path,
        interval        => {
            'start'    => 'OnUnitInactiveSec',
            'interval' => '60s',
        },
        user            => $fetch_dbconfig_user,
        require         => [File[$fetch_dbconfig_path], File['/srv/dbconfig']],
        logging_enabled => false,
    }

    # Monitoring
    prometheus::blackbox::check::http { 'noc.wikimedia.org':
        team        => 'noc',
        severity    => 'critical',
        path        => '/',
        ip_families => ['ip4'],
        force_tls   => true,
    }

    profile::auto_restarts::service { 'apache2': }
    profile::auto_restarts::service { 'envoyproxy': }
    profile::auto_restarts::service { 'php7.4-fpm': }
}
