# Class: icinga
#
# Sets up an icinga server, with appropriate config & plugins
# FIXME: A lot of code in here (init script, user setup, logrotate,
# and others) should probably come from the icinga deb package,
# and not from puppet. Investigate and potentially fix this.
# Note that our paging infrastructure (AQL as of 20161101) may need
# an update of it's sender whitelist. And don't forget to do an end-to-end
# test. That is submit a passive check of DOWN for a paging service and confirm
# people get the pages.
class icinga(
    String $icinga_user,
    String $icinga_group,
    Integer[0, 1] $enable_notifications  = 1,
    Integer[0, 1] $enable_event_handlers = 1,
    Enum['stopped', 'running'] $ensure_service = 'running',
    Array[Stdlib::Unixpath] $cfg_files = [
        '/etc/nagios/puppet_hostgroups.cfg',     # Backwards-compatibility
        '/etc/nagios/puppet_servicegroups.cfg',
        '/etc/nagios/nagios_host.cfg',           # Locally-generated hosts (routers, pdus, et. al. -- not naggen2)
        '/etc/nagios/nagios_service.cfg',
    ],
    Array[Stdlib::Unixpath] $cfg_dirs = [
        '/etc/icinga/commands'
    ],
    Stdlib::Unixpath $retention_file = '/var/cache/icinga/retention.dat',
    Integer $max_concurrent_checks = 0,
    Integer[1] $logs_keep_days = 780,
    Boolean $stub_contactgroups = false,
) {

    ensure_packages(['icinga', 'python3-yaml', 'patch', 'python3-clustershell'])

    file { $cfg_files:
      ensure => 'file',
      mode   => '0444',
      notify => Service['icinga'],
    }

    # Replaces custom icinga init script.
    file { '/etc/default/icinga':
      source  => 'puppet:///modules/icinga/default_icinga.sh',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => Package['icinga']
    }

    systemd::service { 'icinga':
        ensure         => 'present',
        content        => systemd_template('icinga'),
        service_params => {
            hasstatus => false,
            restart   => '/etc/init.d/icinga reload',
        },
        require        => [
          Mount['/var/icinga-tmpfs'],
          Package['icinga'],
        ],
    }

    file { '/etc/icinga/icinga.cfg':
      content => template('icinga/icinga.cfg.erb'),
      owner   => $icinga_user,
      group   => $icinga_group,
      mode    => '0644',
      require => Package['icinga'],
      notify  => Service['icinga'],
    }

    # Clear the objects directory of sample configuration
    file { '/etc/icinga/objects':
      ensure  => 'directory',
      purge   => true,
      recurse => true,
    }

    class { '::nagios_common::contactgroups':
      source     => 'puppet:///modules/nagios_common/contactgroups.cfg',
      owner      => $icinga_user,
      group      => $icinga_group,
      config_dir => '/etc/icinga/objects',
      require    => Package['icinga'],
      notify     => Service['icinga'],
    }

    if ($stub_contactgroups) {
        if ( $::realm == 'production' ) {
            fail('Do not use $stub_contactgroups in production')
        }

        # Icinga needs all contactgroups' members to be defined. Pretend 'stub'
        # contact (defined in labs/private.git) is part of all contactgroups.
        # For testing only!
        exec { 'stub_contactgroups':
            command => '/usr/bin/sed -i "s/members.*/members stub/" /etc/icinga/objects/contactgroups.cfg',
            require => Class['Nagios_common::Contactgroups'],
        }
    }

    class { '::nagios_common::contacts':
      owner      => $icinga_user,
      group      => $icinga_group,
      config_dir => '/etc/icinga/objects',
      content    => secret('nagios/contacts.cfg'),
      require    => Package['icinga'],
      notify     => Service['icinga'],
    }

    class { [
        '::nagios_common::timeperiods',
        '::nagios_common::notification_commands',
    ] :
      owner      => $icinga_user,
      group      => $icinga_group,
      config_dir => '/etc/icinga/objects',
      require    => Package['icinga'],
      notify     => Service['icinga'],
    }

    # manages resource.cfg and does not belong in /etc/icinga/objects
    class { '::nagios_common::user_macros':
      owner   => $icinga_user,
      group   => $icinga_group,
      require => Package['icinga'],
      notify  => Service['icinga'],
    }

    file { '/etc/icinga/objects/nsca_frack.cfg':
        content => template('icinga/nsca_frack.cfg.erb'),
        owner   => $icinga_user,
        group   => $icinga_group,
        mode    => '0644',
        require => Package['icinga'],
        notify  => Service['icinga'],
    }

    $command_file='/var/lib/icinga/rw'

    file { '/var/log/icinga/icinga.log':
        ensure => 'present',
        mode   => '0644',
        owner  => $icinga_user,
        group  => $icinga_group,
    }

    # If hosts appear to be missing from the web ui, it might be
    # the permissions on this file.  Requires a restart if changed.
    file { '/var/cache/icinga/objects.cache':
        ensure => 'present',
        mode   => '0644',
        owner  => $icinga_user,
        group  => 'www-data',
        notify => Service['icinga'],
    }

    file { '/etc/icinga/cgi.cfg':
        source  => 'puppet:///modules/icinga/cgi.cfg',
        owner   => $icinga_user,
        group   => $icinga_group,
        mode    => '0644',
        require => Package['icinga'],
        notify  => Service['icinga'],
    }


    # Setup all plugins!
    class { '::icinga::plugins':
        icinga_user  => $icinga_user,
        icinga_group => $icinga_group,
        require      => Package['icinga'],
        notify       => Service['icinga'],
    }

    # Setup tmpfs for use by icinga
    file { '/var/icinga-tmpfs':
        ensure => directory,
        owner  => $icinga_user,
        group  => $icinga_group,
        mode   => '0755',
    }

    mount { '/var/icinga-tmpfs':
        ensure  => mounted,
        atboot  => true,
        fstype  => 'tmpfs',
        device  => 'none',
        options => "size=1024m,uid=${icinga_user},gid=${icinga_group},mode=755",
        require => File['/var/icinga-tmpfs'],
    }

    # Ensure periodic cleanup
    systemd::tmpfile { 'icinga-tmpfs':
        ensure  => present,
        content => 'e /var/icinga-tmpfs/ - - - 1d',
    }

    file { '/var/lib/icinga':
        ensure => directory,
        owner  => $icinga_user,
        group  => $icinga_group,
    }

    file { '/var/cache/icinga':
        ensure => directory,
        owner  => $icinga_user,
        group  => 'www-data',
    }

    # Script to purge resources for non-existent hosts
    file { '/usr/local/sbin/purge-nagios-resources.py':
        source => 'puppet:///modules/icinga/purge-nagios-resources.py',
        owner  => $icinga_user,
        group  => $icinga_group,
        mode   => '0755',
    }

    # Command folders / files to let icinga web to execute commands
    # See Debian Bug 571801
    file { $command_file:
        ensure => 'directory',
        owner  => $icinga_user,
        group  => 'www-data',
        mode   => '2710', # The sgid bit means new files inherit guid
    }

    # ensure icinga can write logs for ircecho, raid_handler etc.
    file { '/var/log/icinga':
        ensure => 'directory',
        owner  => $icinga_user,
        group  => 'adm',
        mode   => '2755',
    }

    # archive location for rotated logs, use the space in /srv/
    file { '/srv/icinga-logs':
        ensure => 'directory',
        owner  => $icinga_user,
        group  => 'adm',
        mode   => '2755',
    }

    # Complement Icinga's log archival/rotation with tmpfiles.d cleanup
    systemd::tmpfile { 'icinga-logs':
        ensure  => present,
        content => "e /srv/icinga-logs/ - - - ${logs_keep_days}d",
    }

    # Check that the icinga config is sane
    monitoring::service { 'check_icinga_config':
        description    => 'Check correctness of the icinga configuration',
        check_command  => 'check_icinga_config',
        check_interval => 10,
        notes_url      => 'https://wikitech.wikimedia.org/wiki/Icinga',
    }

    # script to manually send SMS to Icinga contacts (T82937)
    file { '/usr/local/bin/icinga-sms':
        ensure => present,
        source => 'puppet:///modules/icinga/icinga-sms.py',
        owner  => 'root',
        group  => 'root',
        mode   => '0550',
    }

    # Script to generate the contacts configuration for the Icinga meta-monitoring
    file { '/usr/local/bin/generate-check-icinga-contacts':
        ensure  => present,
        owner   => 'root',
        group   => $icinga_group,
        mode    => '0550',
        source  => 'puppet:///modules/icinga/generate_check_icinga_contacts.py',
        require => Package['python3-yaml'],
    }

    # Script to sync the contacts configuration for the Icinga meta-monitoring
    file { '/usr/local/bin/sync-check-icinga-contacts':
        ensure => present,
        owner  => 'root',
        group  => $icinga_group,
        mode   => '0550',
        source => 'puppet:///modules/icinga/sync_check_icinga_contacts.sh',
    }

    # Script to parse and query the status.dat file
    file { '/usr/local/bin/icinga-status':
        ensure  => present,
        owner   => 'root',
        group   => 'ops',
        mode    => '0550',
        source  => 'puppet:///modules/icinga/icinga_status.py',
        require => Package['python3-clustershell'],
    }

    # Purge unmanaged nagios_host and nagios_services resources
    # This will only happen for non exported resources, that is resources that
    # are declared by the icinga host itself
    resources { 'nagios_host':
        purge  => true,
        notify => Service['icinga'],
    }

    resources { 'nagios_service':
        purge  => true,
        notify => Service['icinga'],
    }

    # Applies a patch to disable autocomplete.js on search text input
    $patches_dir = '/usr/share/icinga/patches'

    file { $patches_dir:
        ensure  => 'directory'
    }

    file { "${patches_dir}/disable_autocomplete.patch":
        ensure  => 'present',
        source  => "puppet:///modules/${module_name}/disable_autocomplete.patch",
        require => File[$patches_dir]
    }

    exec { 'apply disable_autocomplete.patch':
        command => "/usr/bin/patch --forward /usr/share/icinga/htdocs/menu.html ${patches_dir}/disable_autocomplete.patch",
        unless  => "/usr/bin/patch --reverse --dry-run -f /usr/share/icinga/htdocs/menu.html ${patches_dir}/disable_autocomplete.patch",
        require => File["${patches_dir}/disable_autocomplete.patch"],
    }
}
