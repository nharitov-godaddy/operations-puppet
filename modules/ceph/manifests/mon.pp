# Class: ceph::mon
#
# This class manages the Ceph admin client.
#
# Parameters
#    - $data_dir
#        Path to the base Ceph data directory
#    - $admin_keyring
#        File name and path to install the admin keyring
#    - $mon_keydata
#        base64 encoded key used to create the monitor keyring
#    - $fsid
#        Ceph filesystem ID
class ceph::mon(
    Stdlib::AbsolutePath $admin_keyring,
    Stdlib::Unixpath     $data_dir,
    String               $mon_keydata,
    String               $fsid,
) {
    if defined(Ceph::Auth::Keyring['admin']) {
        Ceph::Auth::Keyring['admin'] -> Class['ceph::mon']
    } else {
        notify {'ceph::mon: admin keyring not defined, things might not work as expected.': }
    }

    $keyring = "${data_dir}/tmp/ceph.mon.keyring"

    file { "${data_dir}/mon/ceph-${::hostname}":
        ensure => 'directory',
        owner  => 'ceph',
        group  => 'ceph',
        mode   => '0750',
    }

    ceph::keyring { 'mon.':
        cap_mon => 'allow *',
        keyring => $keyring,
        keydata => $mon_keydata,
        notify  => Exec['import-keyring-admin'],
    }

    exec { 'import-keyring-admin':
        command     => "/usr/bin/ceph-authtool ${keyring} \
                        --import-keyring ${admin_keyring}",
        refreshonly => true,
    }
    if defined(Ceph::Auth::Keyring['admin']) {
        Ceph::Auth::Keyring['admin'] -> Exec['import-keyring-admin']
    } else {
        notify {'ceph::mon: Admin keyring not defined, things might not work as expected.': }
    }

    exec { 'ceph-mon-mkfs':
        command => "/usr/bin/ceph-mon --mkfs -i ${::hostname} \
                    --fsid ${fsid} --keyring ${keyring}",
        user    => 'ceph',
        creates => "${data_dir}/mon/ceph-${::hostname}/kv_backend",
        require => [Ceph::Keyring['mon.'], File["${data_dir}/mon/ceph-${::hostname}"]],
    }

    service { "ceph-mon@${::hostname}":
        ensure  => running,
        enable  => true,
        require => [Exec['ceph-mon-mkfs'], File['/etc/ceph/ceph.conf']],
    }
}
