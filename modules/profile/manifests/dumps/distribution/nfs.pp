# SPDX-License-Identifier: Apache-2.0
# Set up NFS Server for the public dumps servers
# Firewall rules are managed separately through profile::wmcs::nfs::ferm

class profile::dumps::distribution::nfs (
    Array[Stdlib::Host] $nfs_clients = lookup('profile::dumps::distribution::nfs_clients'),
){

    ensure_packages(['nfs-kernel-server', 'nfs-common', 'rpcbind'])

    file { '/etc/default/nfs-common':
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        source => 'puppet:///modules/profile/dumps/distribution/nfs-common',
    }

    file { '/etc/default/nfs-kernel-server':
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        source => 'puppet:///modules/profile/dumps/distribution/nfs-kernel-server',
    }

    file { '/etc/modprobe.d/nfs-lockd.conf':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => 'options lockd nlm_udpport=32768 nlm_tcpport=32769',
    }

    file { '/etc/exports':
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        content => template('profile/dumps/distribution/nfs-exports.erb'),
        require => Package['nfs-kernel-server'],
    }

    service { 'nfs-kernel-server':
        enable  => true,
        require => Package['nfs-kernel-server'],
    }

    firewall::service { 'labstore_analytics_nfs_nfs_service':
        proto    => 'tcp',
        port     => 2049,
        src_sets => ['ANALYTICS_NETWORKS'],
    }

    monitoring::service { 'nfs':
        description   => 'NFS',
        check_command => 'check_tcp!2049',
        notes_url     => 'https://wikitech.wikimedia.org/wiki/Portal:Data_Services/Admin/Labstore',
    }

    profile::auto_restarts::service { 'rpcbind':}
    profile::auto_restarts::service { 'nfs-idmapd':}
    profile::auto_restarts::service { 'nfs-blkmap':}
    profile::auto_restarts::service { 'nfs-mountd':}
}
