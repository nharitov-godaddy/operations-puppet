class role::dumps::generation::server::spare {
    system::role { 'dumps::generation::server': description => 'spare NFS server of dumps generation filesystem to dumps producer hosts' }

    include ::profile::base::production
    include ::profile::firewall
    include ::profile::dumps::nfs
    include ::profile::dumps::generation::server::rsync_firewall
    include ::profile::dumps::rsyncer_peer
    include ::profile::dumps::generation::server::cleanup
    include ::profile::dumps::generation::server::common
}