# phabricator instance
#
class role::phabricator {

    system::role { 'phabricator':
        description => 'Phabricator (Main) Server'
    }

    include ::profile::base::production
    include ::profile::firewall
    include ::profile::backup::host
    include ::profile::phabricator::main
    include ::profile::phabricator::logmail
    include ::profile::phabricator::httpd
    include ::profile::phabricator::monitoring
    include ::profile::phabricator::performance
    include ::profile::prometheus::apache_exporter
    include ::profile::tlsproxy::envoy # TLS termination
    include ::rsync::server # copy repo data between servers
}
