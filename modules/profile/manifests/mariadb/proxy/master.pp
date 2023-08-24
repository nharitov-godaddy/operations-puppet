# proxy in with 2 hosts, active-passive (with failover) scenario
class profile::mariadb::proxy::master (
    $primary_name   = lookup('profile::mariadb::proxy::master::primary_name'),
    $primary_addr   = lookup('profile::mariadb::proxy::master::primary_addr'),
    $secondary_name = lookup('profile::mariadb::proxy::master::secondary_name'),
    $secondary_addr = lookup('profile::mariadb::proxy::master::secondary_addr'),
    ) {

    $master_template = 'db-master.cfg.erb'

    file { '/etc/haproxy/conf.d/db-master.cfg':
        owner   => 'haproxy',
        group   => 'haproxy',
        mode    => '0440',
        content => template("profile/mariadb/proxy/${master_template}"),
    }

    nrpe::monitor_service { 'haproxy_failover':
        description  => 'haproxy failover',
        nrpe_command => '/usr/local/lib/nagios/plugins/check_haproxy --check=failover',
        notes_url    => 'https://wikitech.wikimedia.org/wiki/HAProxy',
    }
}
