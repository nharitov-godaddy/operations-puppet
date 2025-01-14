# SPDX-License-Identifier: Apache-2.0

class openstack::keystone::service::antelope::bookworm(
    Stdlib::Port $public_bind_port,
    Stdlib::Port $admin_bind_port,
) {
    require ::openstack::serverpackages::antelope::bookworm

    $packages = [
        'keystone',
        'alembic',
        'ldapvi',
        'python3-ldappool',
        'python3-ldap3',
        'ruby-ldap',
        'python3-mwclient',
    ]

    ensure_packages($packages)

    # Temporary (?) time-out for apache + mod_wsgi which don't work with Keystone
    # on bookworm
    file { '/etc/init.d/keystone':
        mode    => '0755',
        content => template('openstack/antelope/keystone/keystone-public-service.erb'),
        require => Package['keystone'];
    }
    file { '/etc/init.d/keystone-admin':
        mode    => '0755',
        content => template('openstack/antelope/keystone/keystone-admin-service.erb'),
        require => Package['keystone'];
    }
    service {'keystone':
        ensure  => 'running',
        require => File['/etc/init.d/keystone'];
    }
    service {'keystone-admin':
        ensure  => 'running',
        require => File['/etc/init.d/keystone-admin'];
    }
}
