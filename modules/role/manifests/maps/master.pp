# Sets up a maps server master
class role::maps::master {
    include ::profile::base::production
    include ::profile::rsyslog::udp_localhost_compat
    include ::profile::firewall
    include ::profile::lvs::realserver

    include ::profile::maps::apps
    include ::profile::maps::osm_master
    include ::profile::maps::tlsproxy
    include ::profile::prometheus::postgres_exporter

    system::role { 'maps::master':
      ensure      => 'present',
      description => 'Maps master (postgresql, kartotherian)',
    }

}
