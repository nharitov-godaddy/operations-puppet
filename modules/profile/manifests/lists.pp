class profile::lists (
    Stdlib::Fqdn $lists_servername            = lookup('mailman::lists_servername'),
    Array[String] $prometheus_nodes           = lookup('prometheus_nodes'),
    Optional[String] $primary_host            = lookup('profile::lists::primary_host', {'default_value' => undef}),
    Optional[String] $standby_host            = lookup('profile::lists::standby_host', {'default_value' => undef}),
    Optional[Stdlib::IP::Address] $lists_ipv4 = lookup('profile::lists::ipv4', {'default_value' => undef}),
    Optional[Stdlib::IP::Address] $lists_ipv6 = lookup('profile::lists::ipv6', {'default_value' => undef}),
){
    include ::network::constants
    include ::privateexim::listserve

    # Disable mailman service on the sandby host
    $mailman_service_ensure = $facts['fqdn'] ? {
        $standby_host => 'stopped',
        default       => 'running',
    }

    class { '::mailman':
        lists_servername       => $lists_servername,
        mailman_service_ensure => $mailman_service_ensure,
    }

    mailalias { 'root': recipient => 'root@wikimedia.org' }

    # This will be a noop if $lists_ipv[46] are undef
    interface::alias { $lists_servername:
        ipv4 => $lists_ipv4,
        ipv6 => $lists_ipv6,
    }

    class { '::sslcert::dhparam': }
    acme_chief::cert{ 'lists':
        puppet_svc => 'apache2',
        key_group  => 'Debian-exim',
    }

    $trusted_networks = $network::constants::aggregate_networks.filter |$x| {
        $x !~ /127.0.0.0|::1/
    }

    class { 'spamassassin':
        required_score   => '4.0',
        use_bayes        => '0',
        bayes_auto_learn => '0',
        trusted_networks => $trusted_networks,
    }

    $list_outbound_ips = [
        pick($lists_ipv4, $facts['ipaddress']),
        pick($lists_ipv6, $facts['ipaddress6']),
    ]

    class { '::exim4':
        variant => 'heavy',
        config  => template('profile/exim/exim4.conf.mailman.erb'),
        filter  => template('profile/exim/system_filter.conf.mailman.erb'),
        require => [
            Class['spamassassin'],
            Interface::Alias[$lists_servername],
        ],
    }

    file { "/etc/exim4/aliases/${lists_servername}":
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => 'puppet:///modules/profile/exim/listserver_aliases',
        require => Class['exim4'],
    }

    exim4::dkim { $lists_servername:
        domain   => $lists_servername,
        selector => 'wikimedia',
        content  => secret("dkim/${lists_servername}-wikimedia.key"),
    }

    backup::set { 'var-lib-mailman': }

    if $primary_host and $standby_host {
        rsync::quickdatacopy { 'var-lib-mailman':
            source_host         => $primary_host,
            dest_host           => $standby_host,
            auto_sync           => false,
            module_path         => '/var/lib/mailman',
            server_uses_stunnel => true,
        }
    }

    monitoring::service { 'smtp':
        description   => 'Exim SMTP',
        check_command => 'check_smtp_tls_le',
        notes_url     => 'https://wikitech.wikimedia.org/wiki/Exim',
    }

    monitoring::service { 'https':
        description   => 'HTTPS',
        check_command => "check_ssl_http_letsencrypt!${lists_servername}",
        notes_url     => 'https://wikitech.wikimedia.org/wiki/Mailman#Monitoring',
    }

    # Don't monitor mailman processes on standby hosts. The mailman service is stopped there.
    if $facts['fqdn'] != $standby_host {

        nrpe::monitor_service { 'procs_mailmanctl':
            description  => 'mailman_ctl',
            nrpe_command => '/usr/lib/nagios/plugins/check_procs -c 1:1 -u list --ereg-argument-array=\'/mailman/bin/mailmanctl\'',
            notes_url    => 'https://wikitech.wikimedia.org/wiki/Mailman#Monitoring',
        }

        nrpe::monitor_service { 'procs_mailman_qrunner':
            description  => 'mailman_qrunner',
            nrpe_command => '/usr/lib/nagios/plugins/check_procs -c 8:8 -u list --ereg-argument-array=\'/mailman/bin/qrunner\'',
            notes_url    => 'https://wikitech.wikimedia.org/wiki/Mailman#Monitoring',
        }

        nrpe::monitor_service { 'mailman_queue':
            description  => 'mailman_queue_size',
            nrpe_command => '/usr/bin/sudo -u list /usr/local/lib/nagios/plugins/check_mailman_queue 25 25 25',
            notes_url    => 'https://wikitech.wikimedia.org/wiki/Mailman#Monitoring',
        }

        sudo::user { 'nagios_mailman_queue':
            user       => 'nagios',
            privileges => ['ALL = (list) NOPASSWD: /usr/local/lib/nagios/plugins/check_mailman_queue'],
        }

    }

    monitoring::service { 'mailman_listinfo':
        description   => 'mailman list info',
        check_command => "check_https_url_for_string!${lists_servername}!/mailman/listinfo/wikimedia-l!\'Wikimedia Mailing List\'",
        notes_url     => 'https://wikitech.wikimedia.org/wiki/Mailman#Monitoring',
    }

    monitoring::service { 'mailman_archives':
        description   => 'mailman archives',
        check_command => "check_https_url_for_string!${lists_servername}!/pipermail/wikimedia-l/!\'The Wikimedia-l Archives\'",
        notes_url     => 'https://wikitech.wikimedia.org/wiki/Mailman#Monitoring',
    }

    monitoring::check_prometheus { 'mailman_hours_until_empty_outbound_queue':
        description     => 'Mailman outbound queue hours until empty.',
        dashboard_links => ['https://grafana.wikimedia.org/d/nULM0E1Wk/mailman'],
        query           => "node_files_total{instance=\"${::hostname}:9100\", path=~\"(.*)mailman/qfiles/out\"}/scalar(rate(mailman_smtp_duration_seconds{instance=\"${::hostname}:3903\"}[10m])/rate(mailman_smtp_total{instance=\"${::hostname}:3903\"}[10m]))/60",
        warning         => 2,  # this value should be tuned to above normal daily utilization. historically, a spike below this happens at 08:00 UTC each day
        critical        => 20, # this value should be tuned to handle abnormal daily utilization. historically, a spike below this happens at the first of each month.
        method          => 'ge',
        check_interval  => 60,
        retry_interval  => 2,
        nan_ok          => true,
        notes_link      => 'https://wikitech.wikimedia.org/wiki/Mailman#Monitoring',
        prometheus_url  => "http://prometheus.svc.${::site}.wmnet/ops",
    }

    prometheus::node_file_count {'track mailman queue depths':
        paths   => [
            '/var/lib/mailman/qfiles/in',
            '/var/lib/mailman/qfiles/bounces',
            '/var/lib/mailman/qfiles/virgin',
            '/var/lib/mailman/qfiles/out',
        ],
        outfile => '/var/lib/prometheus/node.d/mailman_queues.prom'
    }

    file { '/usr/local/lib/nagios/plugins/check_mailman_queue':
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
        source => 'puppet:///modules/icinga/check_mailman_queue.sh',
    }

    # Mtail program to gather smtp send duration and count
    mtail::program { 'mailman':
        ensure => 'present',
        source => 'puppet:///modules/mtail/programs/mailman.mtail',
        notify => Service['mtail'],
    }

    # in buster, the 'list' group has access to /var/log/mailman
    if os_version('debian >= buster') {
        user { 'mtail':
            ensure  => 'present',
            groups  => ['list'],
            require => Package['mailman']
        }
    }

    # Mtail program to gather exim logs
    mtail::program { 'exim':
        ensure => 'present',
        source => 'puppet:///modules/mtail/programs/exim.mtail',
        notify => Service['mtail'],
    }

    $prometheus_nodes_ferm = join($prometheus_nodes, ' ')
    ferm::service { 'mtail':
        proto  => 'tcp',
        port   => '3903',
        srange => "(@resolve((${prometheus_nodes_ferm})) @resolve((${prometheus_nodes_ferm}), AAAA))",
    }

    ferm::service { 'mailman-smtp':
        proto => 'tcp',
        port  => '25',
    }

    ferm::service { 'mailman-http':
        proto => 'tcp',
        port  => '80',
    }

    ferm::service { 'mailman-https':
        proto => 'tcp',
        port  => '443',
    }

    ferm::rule { 'mailman-spamd-local':
        rule => 'proto tcp dport 783 { saddr (127.0.0.1 ::1) ACCEPT; }'
    }
}
