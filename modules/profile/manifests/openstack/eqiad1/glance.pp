class profile::openstack::eqiad1::glance (
    String $version = lookup('profile::openstack::eqiad1::version'),
    Array[Stdlib::Fqdn] $openstack_controllers = lookup('profile::openstack::eqiad1::openstack_controllers'),
    Stdlib::Fqdn $keystone_fqdn = lookup('profile::openstack::eqiad1::keystone_api_fqdn'),
    String $db_pass = lookup('profile::openstack::eqiad1::glance::db_pass'),
    Stdlib::Fqdn $db_host = lookup('profile::openstack::eqiad1::glance::db_host'),
    String $ldap_user_pass = lookup('profile::openstack::eqiad1::ldap_user_pass'),
    Stdlib::Port $api_bind_port = lookup('profile::openstack::eqiad1::glance::api_bind_port'),
    Array[String] $glance_backends = lookup('profile::openstack::eqiad1::glance_backends'),
    String $ceph_pool = lookup('profile::openstack::eqiad1::glance::ceph_pool'),
    Array[Stdlib::Fqdn] $haproxy_nodes = lookup('profile::openstack::eqiad1::haproxy_nodes'),
    Boolean $enforce_policy_scope = lookup('profile::openstack::eqiad1::keystone::enforce_policy_scope'),
    Boolean $enforce_new_policy_defaults = lookup('profile::openstack::eqiad1::keystone::enforce_new_policy_defaults'),
) {

    require ::profile::openstack::eqiad1::clientpackages
    class {'::profile::openstack::base::glance':
        version                     => $version,
        openstack_controllers       => $openstack_controllers,
        keystone_fqdn               => $keystone_fqdn,
        db_pass                     => $db_pass,
        db_host                     => $db_host,
        ldap_user_pass              => $ldap_user_pass,
        api_bind_port               => $api_bind_port,
        glance_backends             => $glance_backends,
        ceph_pool                   => $ceph_pool,
        active                      => true,
        haproxy_nodes               => $haproxy_nodes,
        enforce_policy_scope        => $enforce_policy_scope,
        enforce_new_policy_defaults => $enforce_new_policy_defaults,
    }
    contain '::profile::openstack::base::glance'
}
