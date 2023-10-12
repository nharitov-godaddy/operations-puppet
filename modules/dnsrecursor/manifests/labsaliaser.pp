# == class: dnsrecursor::labsaliaser
#
# Provision a script and systemd timer to setup private IP space answers for dns
# lookups that resolve to public ips and add other misc records.
class dnsrecursor::labsaliaser(
    $username,
    $password,
    $nova_api_url,
    $extra_records,
    $observer_project_name,
) {
    user { 'labsaliaser':
        ensure => present,
        system => true,
        home   => '/nonexistent',
        shell  => '/bin/false',
    }
    file { '/var/cache/labsaliaser':
        ensure  => directory,
        owner   => 'labsaliaser',
        group   => 'labsaliaser',
        mode    => '0644',
        require => User['labsaliaser'],
    }

    $config = {
        'username'              => $username,
        'password'              => $password,
        'output_path'           => '/var/cache/labsaliaser/labs-ip-aliases.json',
        'nova_api_url'          => $nova_api_url,
        'extra_records'         => $extra_records,
        'observer_project_name' => $observer_project_name,
    }

    file { '/etc/labs-dns-alias.yaml':
        ensure  => present,
        owner   => 'labsaliaser',
        group   => 'labsaliaser',
        mode    => '0440',
        content => to_yaml($config),
    }

    package { 'lua-json':
        ensure => present,
    }

    file { '/usr/local/bin/labs-ip-alias-dump.py':
        ensure => present,
        owner  => 'labsaliaser',
        group  => 'labsaliaser',
        mode   => '0550',
        source => 'puppet:///modules/dnsrecursor/labs-ip-alias-dump.py',
    }

    file { '/usr/local/bin/labsalias-dump.sh':
        ensure  => absent,
    }

    systemd::timer::job { 'labs-ip-alias-dump':
        ensure          => 'present',
        # Don't log to file, use journald
        logging_enabled => false,
        user            => 'root',
        description     => 'Update the mapping that splits internal and external DNS for Cloud VPS instances',
        command         => '/usr/local/bin/labs-ip-alias-dump.py',
        interval        => {
            'start'    => 'OnCalendar',
            'interval' => '*-*-* *:30:00', # hourly at half-past
        },
        require         => File[
            '/usr/local/bin/labs-ip-alias-dump.py',
            '/etc/labs-dns-alias.yaml'
        ],
    }
}
