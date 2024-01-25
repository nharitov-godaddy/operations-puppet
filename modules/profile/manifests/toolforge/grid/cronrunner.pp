# Manage the crons for the Toolforge grid users

class profile::toolforge::grid::cronrunner(
    Stdlib::Fqdn $active_host = lookup('profile::toolforge::grid::cronrunner::active_host'),
    Stdlib::Unixpath $sysdir = lookup('profile::toolforge::grid::base::sysdir'),
) {
    include ::profile::toolforge::grid::hba
    include ::profile::toolforge::disable_tool

    $is_active = $active_host == $::facts['fqdn']

    service { 'cron':
        ensure => $is_active.bool2str('running', 'stopped'),
        enable => $is_active,
    }

    # if this is not the active cron runner, block tool crons for easier migration between nodes,
    # but allow root owned crons (most imporantly puppet runs) to still run as intended
    # for more details, see crontab(1)
    file { '/etc/cron.allow':
        ensure  => $is_active.bool2str('absent', 'file'),
        content => "root\n",
    }

    motd::script { 'submithost-banner':
        ensure => present,
        source => "puppet:///modules/profile/toolforge/40-${::wmcs_project}-submithost-banner.sh",
    }

    # We need to include exec environment here since the current
    # version of jsub checks the local environment to find the full
    # path to things before submitting them to the grid. This assumes
    # that jsub is always run in an environment identical to the exec
    # nodes. This is kind of terrible, so we need to fix that eventually.
    # Until then...
    include profile::toolforge::grid::exec_environ

    # This doesn't clearly belong here! Host key authentication is only
    # possible from the bastions and a cron runner is not a bastion.
    # However this is going away in a month or two so I'm just going to
    # leave this here and remove the profile entirely when the time
    # comes.
    file { '/etc/ssh/ssh_config':
        ensure => file,
        mode   => '0444',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/profile/toolforge/grid/bastion/ssh_config',
    }

    file { '/usr/bin/jlocal':
        ensure => present,
        source => 'puppet:///modules/profile/toolforge/jlocal',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
    }

    file { '/usr/local/bin/jlocal':
        ensure  => link,
        target  => '/usr/bin/jlocal',
        owner   => 'root',
        group   => 'root',
        require => File['/usr/bin/jlocal'],
    }

    # Backup crontabs! See https://phabricator.wikimedia.org/T95798
    file { "${sysdir}/crontabs":
        ensure => directory,
        owner  => 'root',
        group  => "${::wmcs_project}.admin",
        mode   => '0770',
    }

    file { "${sysdir}/crontabs/${::fqdn}":
        ensure    => directory,
        source    => '/var/spool/cron/crontabs',
        owner     => 'root',
        group     => "${::wmcs_project}.admin",
        mode      => '0440',
        recurse   => true,
        show_diff => false,
    }

    class { '::rsync::server':
        ensure_service => $is_active.bool2str('running', 'stopped'),
    }

    rsync::server::module { 'crontabs':
        ensure      => $is_active.bool2str('present', 'absent'),
        comment     => 'Toolforge crontabs',
        read_only   => 'yes',
        path        => '/var/spool/cron/crontabs',
        hosts_allow => wmflib::class::hosts('profile::toolforge::grid::cronrunner'),
    }

    systemd::timer::job { 'rsync-crontabs':
        ensure      => $is_active.bool2str('absent', 'present'),
        user        => 'root',
        description => 'rsync crontabs from the active server',
        # add a chmod since the `crontab` group has different GIDs on different servers
        command     => "/bin/sh -c '/usr/bin/rsync -avp --delete rsync://${active_host}/crontabs /var/spool/cron/crontabs && chgrp -R crontab /var/spool/cron/crontabs'",
        interval    => {'start' => 'OnUnitInactiveSec', 'interval' => '10m'},
    }

    systemd::timer::job { 'disable-tool':
        ensure          => $is_active.bool2str('present', 'absent'),
        logging_enabled => false,
        user            => 'root',
        description     => 'Archive crontab for disabled tools',
        command         => '/srv/disable-tool/disable_tool.py crontab',
        interval        => {
        'start'    => 'OnCalendar',
        'interval' => '*:0/2', # every 2 minutes
        },
        require         => Class['::profile::toolforge::disable_tool'],
    }

    systemd::timer::job { 'disable-tool-archive-dbs':
        ensure          => absent,
        logging_enabled => false,
        user            => 'root',
        description     => 'Archive databases for expired tools',
        command         => '/srv/disable-tool/disable_tool.py archivedbs',
        interval        => {
        'start'    => 'OnCalendar',
        'interval' => '*:0/2', # every 2 minutes
        },
    }
}
