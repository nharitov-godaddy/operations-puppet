# SPDX-License-Identifier: Apache-2.0
# Class ganeti
#
# Install ganeti
#
# Parameters:
#   with_drbd: Boolean. Indicates if drbd should be configured. Defaults to true
#
# Actions:
#   Install ganeti and configure modules/LVM. Does NOT initialize a cluster
#
class ganeti(
    String $certname,
    Boolean $with_drbd=true,
    Boolean $use_pki=false,
) {
    ensure_packages('qemu-system-x86')

    # Setup Kernel Same-page Merging to save memory via memory deduplication
    sysfs::parameters { 'ksm':
        values => {
            'kernel/mm/ksm/run'             => '0',
            'kernel/mm/ksm/sleep_millisecs' => '100',
        },
    }

    ensure_packages('ganeti')

    service { 'ganeti':
        ensure => running,
    }

    # We're not using ganeti-instance-debootstrap to create images (we PXE-boot
    # the same images we use for baremetal servers), but /usr/share/ganeti/os/debootstrap
    # is needed as an OS provider for "gnt-instance add"
    ensure_packages(['drbd-utils', 'ovmf', 'ganeti-instance-debootstrap'])

    if $with_drbd {
        kmod::options { 'drbd':
            options => 'minor_count=128 usermode_helper=/bin/true',
        }

        # Enable drbd
        kmod::module { 'drbd':
            ensure => 'present',
        }

        # Disable the systemd service shipped with the drbd package. Ganeti handles
        # DRBD on its own
        service { 'drbd':
            ensure => 'stopped',
            enable => false,
        }
    }

    # Enable vhost_net
    kmod::module { 'vhost_net':
        ensure => 'present',
    }

    # lvm.conf
    # Note: We deviate from the default lvm.conf to change the filter config to
    # not include all block devices. TODO: Do it via augeas
    file { '/etc/lvm/lvm.conf' :
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0644',
        source => 'puppet:///modules/ganeti/lvm.conf',
    }

    if $use_pki {
        $ssl_paths = profile::pki::get_cert('discovery', $certname, {
            'owner'           => 'root',
            'group'           => 'gnt-admin',
            'notify_services' => ['ganeti'],
            'outdir'          => '/etc/ganeti/ssl/',
        })

        sslcert::certificate { $certname:
            ensure     => absent,
        }

        $rapi_ssl_key = $ssl_paths['key']
        $rapi_ssl_cert = $ssl_paths['cert']

    } else {
        sslcert::certificate { $certname:
            ensure     => present,
            group      => 'gnt-admin',
            use_cergen => true,
        }
        $rapi_ssl_key = "/etc/ssl/private/${certname}.key"
        $rapi_ssl_cert = "/etc/ssl/localcerts/${certname}.crt"
    }

    # Deploy defaults (for now, configuring RAPI) and the certificates for RAPI.
    # Potential fixme: We don't restart the daemon here since it's not independent
    # and this file configures other aspects of Ganeti. Manually restart ganeti
    # on the target hosts after changes are merged.
    file { '/etc/default/ganeti':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('ganeti/etc_default_ganeti.erb')
    }
}
