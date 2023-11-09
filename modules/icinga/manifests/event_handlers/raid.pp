# = Class: icinga::event_handlers::raid
#
# Sets up icinga RAID event handler
class icinga::event_handlers::raid (
    String $icinga_user,
    String $icinga_group,
){
    include ::passwords::phabricator

    class { '::phabricator::bot':
        username => 'ops-monitoring-bot',
        token    => $passwords::phabricator::ops_monitoring_bot_token,
        owner    => $icinga_user,
        group    => $icinga_group,
    }

    ensure_packages(['python3-phabricator'])

    file { '/usr/lib/nagios/plugins/eventhandlers/raid_handler':
        source  => 'puppet:///modules/icinga/raid_handler.py',
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => [
            File['/etc/phabricator_ops-monitoring-bot.conf'],
            Package['icinga'],
        ],
    }

    nagios_common::check_command::config { 'raid_handler':
        ensure     => present,
        content    => template('icinga/event_handlers/raid_handler.cfg.erb'),
        config_dir => '/etc/icinga',
        owner      => $icinga_user,
        group      => $icinga_group,
        require    => File['/usr/lib/nagios/plugins/eventhandlers/raid_handler'],
    }
}
