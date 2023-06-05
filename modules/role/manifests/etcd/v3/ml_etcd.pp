# Role to configure an etcd v3 cluster for use in ml_etcd/ml_serve.

class role::etcd::v3::ml_etcd {
    include ::profile::base::production
    include ::profile::firewall
    include ::profile::etcd::v3

    system::role { 'role::etcd::v3::ml_etcd':
        description => 'ml_etcd etcd cluster member'
    }
}
