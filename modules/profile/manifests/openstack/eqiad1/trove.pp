class profile::openstack::eqiad1::trove(
    String              $version                 = lookup('profile::openstack::eqiad1::version'),
    Array[Stdlib::Fqdn] $openstack_controllers   = lookup('profile::openstack::eqiad1::openstack_controllers'),
    String              $db_pass                 = lookup('profile::openstack::eqiad1::trove::db_pass'),
    String              $db_name                 = lookup('profile::openstack::eqiad1::trove::db_name'),
    Stdlib::Fqdn        $db_host                 = lookup('profile::openstack::eqiad1::trove::db_host'),
    String              $ldap_user_pass          = lookup('profile::openstack::eqiad1::ldap_user_pass'),
    Stdlib::Fqdn        $keystone_fqdn           = lookup('profile::openstack::eqiad1::keystone_api_fqdn'),
    String              $region                  = lookup('profile::openstack::eqiad1::region'),
    String              $rabbit_pass             = lookup('profile::openstack::eqiad1::nova::rabbit_pass'),
    String              $trove_guest_rabbit_pass = lookup('profile::openstack::eqiad1::trove::trove_guest_rabbit_pass'),
    String              $trove_service_user_pass = lookup('profile::openstack::eqiad1::trove::trove_user_pass'),
    String              $trove_quay_user         = lookup('profile::openstack::eqiad1::trove::quay_user'),
    String              $trove_quay_pass         = lookup('profile::openstack::eqiad1::trove::quay_pass'),
    ) {

    class {'::profile::openstack::base::trove':
        version                 => $version,
        openstack_controllers   => $openstack_controllers,
        db_pass                 => $db_pass,
        db_name                 => $db_name,
        db_host                 => $db_host,
        ldap_user_pass          => $ldap_user_pass,
        keystone_fqdn           => $keystone_fqdn,
        region                  => $region,
        rabbit_pass             => $rabbit_pass,
        trove_guest_rabbit_pass => $rabbit_pass,
        trove_service_user_pass => $trove_service_user_pass,
        trove_quay_user         => $trove_quay_user,
        trove_quay_pass         => $trove_quay_pass,
    }
}
