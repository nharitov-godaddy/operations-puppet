class role::configcluster {
    system::role { 'Configcluster':
        description => 'Configuration cluster server'
    }
    include ::profile::base::production
    include ::profile::firewall

    include ::profile::zookeeper::server
    include ::profile::zookeeper::firewall

    include ::profile::etcd::v3
    include ::profile::etcd::tlsproxy
    include ::profile::etcd::replication
    # etcd backup
    include ::profile::backup::host
}
