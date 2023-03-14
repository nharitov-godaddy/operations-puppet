class role::wmcs::nfs::primary {
    system::role { $name:
        description => 'NFS primary share cluster',
    }

    include ::profile::base::production
    include ::profile::ldap::client::labs
    include ::profile::base::firewall
    include ::profile::base::cloud_production
    include ::profile::wmcs::nfs::ferm
    include ::profile::wmcs::nfs::primary
    include ::profile::wmcs::services::toolsdb_replica_cnf
}
