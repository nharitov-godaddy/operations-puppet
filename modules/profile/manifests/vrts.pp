# SPDX-License-Identifier: Apache-2.0
# vim: set ts=4 et sw=4:
# sets up an instance of the 'Volunteer Response Team System'
# https://wikitech.wikimedia.org/wiki/VRT_System
class profile::vrts(
    Stdlib::Fqdn $vrts_database_host = lookup('profile::vrts::database_host'),
    String $vrts_database_name       = lookup('profile::vrts::database_name'),
    String $vrts_database_user       = lookup('profile::vrts::database_user'),
    String $vrts_database_pw         = lookup('profile::vrts::database_pass'),
    String $vrts_database_port       = lookup('profile::vrts::database_port'),
    Boolean $vrts_daemon             = lookup('profile::vrts::daemon'),
    String $exim_database_name       = lookup('profile::vrts::exim_database_name'),
    String $exim_database_user       = lookup('profile::vrts::exim_database_user'),
    String $exim_database_pass       = lookup('profile::vrts::exim_database_pass'),
    String $download_url             = lookup('profile::vrts::download_url'),
    String $http_proxy               = lookup('profile::vrts::http_proxy'),
    String $https_proxy              = lookup('profile::vrts::https_proxy'),
    Boolean $local_database          = lookup('profile::vrts::local_database', {default_value => false}),
){
    include network::constants
    include ::profile::prometheus::apache_exporter

    if $local_database {
        include ::profile::mariadb::generic_server
    }

    $trusted_networks = $network::constants::aggregate_networks.filter |$x| {
        $x !~ /127.0.0.0|::1/
    }

    class { '::vrts':
        vrts_database_host => $vrts_database_host,
        vrts_database_name => $vrts_database_name,
        vrts_database_user => $vrts_database_user,
        vrts_database_pw   => $vrts_database_pw,
        vrts_database_port => $vrts_database_port,
        vrts_daemon        => $vrts_daemon,
        exim_database_name => $exim_database_name,
        exim_database_user => $exim_database_user,
        exim_database_pass => $exim_database_pass,
        trusted_networks   => $trusted_networks,
        download_url       => $download_url,
        http_proxy         => $http_proxy,
        https_proxy        => $https_proxy,
    }

    class { '::httpd':
        modules => ['headers', 'rewrite', 'perl'],
    }

    profile::auto_restarts::service { 'apache2': }
    profile::auto_restarts::service { 'envoyproxy': }

    # TODO: On purpose here since it references a file not in a module which is
    # used by other classes as well
    # lint:ignore:puppet_url_without_modules
    file { '/etc/exim4/wikimedia_domains':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => 'puppet:///modules/role/exim/wikimedia_domains',
        require => Class['exim4'],
    }
    # lint:endignore

    ferm::service { 'vrts_http':
        proto  => 'tcp',
        port   => '80',
        srange => '$CACHES',
    }

    $smtp_ferm = join($::mail_smarthost, ' ')
    ferm::service { 'vrts_smtp':
        proto  => 'tcp',
        port   => '25',
        srange => "@resolve((${smtp_ferm}))",
    }

    monitoring::service { 'smtp':
        description   => 'OTRS SMTP',
        check_command => 'check_smtp',
        notes_url     => 'https://wikitech.wikimedia.org/wiki/OTRS#Troubleshooting',
    }

    nrpe::monitor_service{ 'clamd':
        description  => 'clamd running',
        nrpe_command => '/usr/lib/nagios/plugins/check_procs -w 1:1 -c 1:1 -u clamav -C clamd',
        notes_url    => 'https://wikitech.wikimedia.org/wiki/OTRS#ClamAV',
    }
    nrpe::monitor_service{ 'freshclam':
        description  => 'freshclam running',
        nrpe_command => '/usr/lib/nagios/plugins/check_procs -w 1:1 -c 1:1 -u clamav -C freshclam',
        notes_url    => 'https://wikitech.wikimedia.org/wiki/OTRS#ClamAV',
    }

    prometheus::blackbox::check::http { 'ticket.wikimedia.org':
        team               => 'serviceops-collab',
        severity           => 'warning',
        path               => '/otrs/index.pl',
        port               => 1443,
        ip_families        => ['ip4'],
        force_tls          => true,
        body_regex_matches => ['wikimedia'],
    }

    # can conflict with ferm module
    ensure_packages('libnet-dns-perl')
}
