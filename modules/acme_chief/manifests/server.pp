# SPDX-License-Identifier: Apache-2.0
class acme_chief::server (
    Hash[String, Hash[String, String]] $accounts = {},
    Hash[String, Acme_chief::Certificate] $certificates = {},
    Hash[String, Hash[String, Any]] $challenges = {},
    String $http_proxy = '',
    Wmflib::Ensure $http_challenge_support = absent,
    Stdlib::Fqdn $active_host = '',
    Variant[String, Array[Stdlib::Fqdn]] $passive_host = [],
    Array[Stdlib::Fqdn] $authdns_hosts = [],
    Integer $watchdog_sec = 0,
    Stdlib::Unixpath $ssl_client_certificate = $facts['puppet_config']['localcacert'],
) {
    $is_active = $::fqdn == $active_host
    $passive_hosts = [$passive_host].flatten()

    ensure_packages([
        'python3-clustershell', # For the gdnsd-sync script
        'rsync', # For certificate syncing
    ])

    systemd::sysuser { 'acme-chief':
        shell    => '/bin/bash',
    }

    ssh::userkey { 'acme-chief':
        content => secret('keyholder/authdns_acmechief.pub'),
    }

    package { 'acme-chief':
        ensure  => present,
        require => Exec['apt-get update'],
    }

    file { '/etc/acme-chief/conf.d':
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        recurse => true,
        purge   => true,
        require => Package['acme-chief']
    }

    $challenge_conf = has_key($challenges, 'dns-01')? {
        true    => {
            'dns-01' => {
                zone_update_cmd          => $challenges['dns-01']['zone_update_cmd'],
                issuing_ca               => $challenges['dns-01']['issuing_ca'],
                ns_records               => $challenges['dns-01']['ns_records'],
                sync_dns_servers         => $authdns_hosts,
                validation_dns_servers   => $authdns_hosts,
                resolver_port            => $challenges['dns-01']['resolver_port'],
            }
        },
        default => {},
    }

    $config = {
        accounts     => $accounts.map |String $account, Hash[String, String] $account_details| {
            $ret = {
                id        => $account,
                directory => $account_details['directory'],
            }
            if has_key($account_details, 'default') {
                merge($ret, { default => $account_details['default'] })
            } else {
                $ret
            }
        },
        certificates => $certificates,
        challenges   => $challenge_conf,
    }

    file { '/etc/acme-chief/config.yaml':
        owner   => 'acme-chief',
        group   => 'acme-chief',
        mode    => '0444',
        content => to_yaml($config),
        notify  => [
            Base::Service_unit['uwsgi-acme-chief'],
            Service['acme-chief'],
        ],
        require => Package['acme-chief'],
    }

    $certs_path = '/var/lib/acme-chief/certs'
    file { '/etc/acme-chief/cert-sync.conf':
        owner   => 'acme-chief',
        group   => 'acme-chief',
        mode    => '0444',
        content => template('acme_chief/cert-sync.conf.erb'),
        require => Package['acme-chief'],
    }

    $accounts.each |String $account_id, Hash $account_details| {
        file { "/etc/acme-chief/accounts/${account_id}":
            ensure  => directory,
            require => Package['acme-chief'],
            owner   => 'acme-chief',
            group   => 'acme-chief',
            mode    => '0555',
        }
        file { "/etc/acme-chief/accounts/${account_id}/regr.json":
            require => File["/etc/acme-chief/accounts/${account_id}"],
            before  => Service['acme-chief'],
            owner   => 'acme-chief',
            group   => 'acme-chief',
            mode    => '0444',
            content => $account_details['regr'],
        }
        file { "/etc/acme-chief/accounts/${account_id}/private_key.pem":
            require => File["/etc/acme-chief/accounts/${account_id}"],
            before  => Service['acme-chief'],
            owner   => 'acme-chief',
            group   => 'acme-chief',
            mode    => '0400',
            content => secret("acme_chief/accounts/${account_id}/private_key.pem"),
        }
    }

    $ensure = $is_active? {
        true    => 'present',
        default => 'absent',
    }
    systemd::service { 'acme-chief':
        ensure               => $ensure,
        require              => Package['acme-chief'],
        content              => template('acme_chief/acme-chief.service.erb'),
        override             => true,
        monitoring_enabled   => true,
        monitoring_notes_url => 'https://wikitech.wikimedia.org/wiki/Acme-chief#Monitoring',
        monitoring_critical  => true,
        service_params       => {
            restart   => '/bin/systemctl reload acme-chief',
        },
    }

    # TODO: replace with https://gerrit.wikimedia.org/r/460397
    systemd::timer::job { 'reload-acme-chief-backend':
        ensure             => $ensure,
        description        => 'reload the acme-chief service',
        user               => 'root',
        monitoring_enabled => true,
        send_mail          => true,
        environment        => {'MAILTO' => 'sre-traffic@wikimedia.org'},
        command            => '/bin/systemctl reload acme-chief',
        interval           => {'start' => 'OnUnitInactiveSec', 'interval' => '1h'},
        require            => Service['acme-chief'],
    }

    uwsgi::app { 'acme-chief':
        settings => {
            uwsgi => {
                plugins        => 'python3',
                'wsgi-file'    => '/usr/lib/python3/dist-packages/acme_chief/uwsgi.py',
                callable       => 'app',
                socket         => '/run/uwsgi/acme-chief.sock',
                'chmod-socket' => 600,
            }
        },
        require  => Package['acme-chief'],
    }

    profile::auto_restarts::service { 'uwsgi-acme-chief': }

    require sslcert::dhparam # lint:ignore:wmf_styleguide
    $ssl_settings = ssl_ciphersuite('nginx', 'strong')
    nginx::site { 'acme-chief':
        content => template('acme_chief/acme-chief.nginx.conf.erb'),
        require => [
            Uwsgi::App['acme-chief'],
            File['/etc/ssl/dhparam.pem'],
        ],
    }

    ferm::service { 'acme-chief-api':
        proto  => 'tcp',
        port   => '8140',
        srange => '$DOMAIN_NETWORKS',
    }

    nginx::site { 'acme-chief-http-challenges':
        ensure  => $http_challenge_support,
        content => template('acme_chief/acme-chief-http-challenges.nginx.conf.erb'),
        require => Package['acme-chief'],
    }
    ferm::service { 'acme-chief-http-challenges':
        ensure => $http_challenge_support,
        proto  => 'tcp',
        port   => '80',
        srange => '$DOMAIN_NETWORKS',
    }

    $ensure_passive = (!$is_active)? {
        true    => present,
        default => absent,
    }
    ferm::service { 'acme-chief-ssh-rsync':
        ensure => $ensure_passive,
        proto  => 'tcp',
        port   => '22',
        srange => "(@resolve((${active_host})) @resolve((${active_host}), AAAA))",
    }

    keyholder::agent { 'authdns_acmechief':
        trusted_groups => ['acme-chief'],
    }
    file { '/usr/local/bin/acme-chief-gdnsd-sync.py':
        ensure  => present,
        owner   => 'acme-chief',
        group   => 'acme-chief',
        mode    => '0544',
        source  => 'puppet:///modules/acme_chief/gdnsd-sync.py',
        require => Package['acme-chief'],
    }

    file { '/usr/local/bin/acme-chief-certs-sync':
        ensure => present,
        owner  => 'acme-chief',
        group  => 'acme-chief',
        mode   => '0544',
        source => 'puppet:///modules/acme_chief/certs-sync',
    }

    $ac_backend_process = $is_active? {
        true    => '1:1',
        default => '0:0',
    }
    nrpe::monitor_service { 'acme-chief_backend':
        description  => 'Ensure acme-chief-backend is running only in the active node',
        nrpe_command => "/usr/lib/nagios/plugins/check_procs -c ${ac_backend_process} -a acme-chief-backend",
        require      => Package['acme-chief'],
        notes_url    => 'https://wikitech.wikimedia.org/wiki/Acme-chief',
    }

    nrpe::monitor_service { 'acme-chief_api':
        description  => 'Ensure acme-chief-api is running',
        nrpe_command => "/usr/lib/nagios/plugins/check_procs -c 1:1 -a '/usr/bin/uwsgi --die-on-term --ini /etc/uwsgi/apps-enabled/acme-chief.ini'",
        require      => Package['acme-chief'],
        notes_url    => 'https://wikitech.wikimedia.org/wiki/Acme-chief',
    }

    sudo::user { 'nagios_acme-chief_fileage_checks':
        ensure => absent,
    }

    nrpe::monitor_service { 'cert_sync_active_node':
        ensure       => $ensure,
        description  => 'Ensure cert-sync script runs successfully in the active node',
        nrpe_command => "/usr/lib/nagios/plugins/check_file_age -w 3600 -c 7200 ${certs_path}/.rsync.done",
        sudo_user    => 'acme-chief',
        notes_url    => 'https://wikitech.wikimedia.org/wiki/Acme-chief',
    }

    nrpe::monitor_service { 'cert_sync_passive_node':
        ensure       => $ensure_passive,
        description  => 'Ensure that passive node gets the certificates from the active node as expected',
        nrpe_command => "/usr/lib/nagios/plugins/check_file_age -w 3600 -c 7200 ${certs_path}/.rsync.status",
        sudo_user    => 'acme-chief',
        notes_url    => 'https://wikitech.wikimedia.org/wiki/Acme-chief',
    }

    $timer_ensure = ($is_active and !empty($passive_hosts) and !empty($passive_hosts[0])) ? {
        true  => 'present',
        false => 'absent'
    }
    systemd::timer::job {'acme-chief-certs-sync':
        ensure      => $timer_ensure,
        description => 'Sync acme-chief certificates',
        command     => '/usr/local/bin/acme-chief-certs-sync',
        interval    => {
            'start'    => 'OnCalendar',
            'interval' => '*-*-* *:00/30:00', # every 30 min
        },
        user        => 'acme-chief',
        require     => [File['/etc/acme-chief/cert-sync.conf']],
    }
}
