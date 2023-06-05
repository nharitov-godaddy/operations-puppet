# Role class for the etcdv3 cluster used by kubernetes staging.

class role::etcd::v3::kubernetes::staging {
    include ::profile::base::production
    include ::profile::firewall
    include ::profile::etcd::v3

    system::role { 'role::etcd::v3::kubernetes::staging':
        description => 'kubernetes staging etcd cluster member'
    }
}
