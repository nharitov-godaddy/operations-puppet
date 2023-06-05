# == Class: role::piwik
#
class role::piwik {

    system::role { 'piwik':
        description => 'Analytics Piwik/Matomo server',
    }

    include ::profile::base::production
    include ::profile::firewall

    include ::profile::piwik::webserver
    include ::profile::tlsproxy::envoy
    include ::profile::piwik::instance
    # override profile::backup::enable to disable regular backups
    include ::profile::analytics::backup::database
    include ::profile::piwik::database

}
