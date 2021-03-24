class cinderutils {
    # remove this after a few puppet runs
    file { '/usr/sbin/prepare_cinder_volume':
        ensure => absent,
    }

    file { '/usr/local/sbin/wmcs-prepare-cinder-volume':
        ensure => present,
        source => 'puppet:///modules/cinderutils/wmcs-prepare-cinder-volume.py',
        owner  => 'root',
        group  => 'root',
        mode   => '0554',
    }

    # compat
    file { '/usr/local/sbin/prepare_cinder_volume':
        ensure => link,
        target => '/usr/local/sbin/wmcs-prepare-cinder-volume',
    }
}
