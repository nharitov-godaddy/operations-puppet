class profile::openstack::base::barbican(
    String $version = lookup('profile::openstack::base::version'),
    Array[Stdlib::Fqdn] $openstack_controllers = lookup('profile::openstack::base::openstack_controllers'),
    Stdlib::Fqdn $keystone_fqdn = lookup('profile::openstack::base::keystone_api_fqdn'),
    String $db_user = lookup('profile::openstack::base::barbican::db_user'),
    String $db_name = lookup('profile::openstack::base::barbican::db_name'),
    String $db_pass = lookup('profile::openstack::base::barbican::db_pass'),
    Stdlib::Fqdn $db_host = lookup('profile::openstack::base::barbican::db_host'),
    String $ldap_user_pass = lookup('profile::openstack::base::ldap_user_pass'),
    Stdlib::Port $bind_port = lookup('profile::openstack::base::barbican::bind_port'),
    String $crypto_kek = lookup('profile::openstack::base::barbican::kek'),
    Array[Stdlib::Fqdn] $haproxy_nodes = lookup('profile::openstack::base::haproxy_nodes'),
) {

    class { '::openstack::barbican::service':
        version         => $version,
        memcached_nodes => $openstack_controllers,
        keystone_fqdn   => $keystone_fqdn,
        db_user         => $db_user,
        db_pass         => $db_pass,
        crypto_kek      => $crypto_kek,
        db_name         => $db_name,
        db_host         => $db_host,
        ldap_user_pass  => $ldap_user_pass,
        bind_port       => $bind_port,
    }

    ferm::service { 'barbican-api-backend':
        proto  => 'tcp',
        port   => $bind_port,
        srange => "@resolve((${haproxy_nodes.join(' ')}))",
    }

    openstack::db::project_grants { 'barbican':
        access_hosts => $haproxy_nodes,
        db_name      => 'barbican',
        db_user      => $db_user,
        db_pass      => $db_pass,
        require      => Package['barbican-api'],
    }
}
