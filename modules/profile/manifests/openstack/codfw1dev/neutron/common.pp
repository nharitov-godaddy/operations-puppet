# SPDX-License-Identifier: Apache-2.0
class profile::openstack::codfw1dev::neutron::common(
    Stdlib::Fqdn $db_host = lookup('profile::openstack::codfw1dev::neutron::db_host'),
    $version = lookup('profile::openstack::codfw1dev::version'),
    $region = lookup('profile::openstack::codfw1dev::region'),
    $dhcp_domain = lookup('profile::openstack::codfw1dev::nova::dhcp_domain'),
    $db_pass = lookup('profile::openstack::codfw1dev::neutron::db_pass'),
    Array[OpenStack::ControlNode] $openstack_control_nodes = lookup('profile::openstack::codfw1dev::openstack_control_nodes'),
    Array[Stdlib::Fqdn] $rabbitmq_nodes = lookup('profile::openstack::codfw1dev::rabbitmq_nodes'),
    Array[Stdlib::Host] $haproxy_nodes = lookup('profile::openstack::codfw1dev::haproxy_nodes'),
    Stdlib::Fqdn $keystone_api_fqdn = lookup('profile::openstack::codfw1dev::keystone_api_fqdn'),
    $ldap_user_pass = lookup('profile::openstack::codfw1dev::ldap_user_pass'),
    $rabbit_pass = lookup('profile::openstack::codfw1dev::neutron::rabbit_pass'),
    $agent_down_time = lookup('profile::openstack::codfw1dev::neutron::agent_down_time'),
    $log_agent_heartbeats = lookup('profile::openstack::codfw1dev::neutron::log_agent_heartbeats'),
    Stdlib::Port $bind_port = lookup('profile::openstack::codfw1dev::neutron::bind_port'),
    Boolean $enforce_policy_scope = lookup('profile::openstack::codfw1dev::keystone::enforce_policy_scope'),
    Boolean $enforce_new_policy_defaults = lookup('profile::openstack::codfw1dev::keystone::enforce_new_policy_defaults'),
    Array[String[1]] $type_drivers = lookup('profile::openstack::codfw1dev::neutron::type_drivers', {default_value => ['flat', 'vlan', 'vxlan']}),
    Array[String[1]] $tenant_network_types = lookup('profile::openstack::codfw1dev::neutron::tenant_network_types', {default_value => ['vxlan']}),
    Array[String[1]] $mechanism_drivers = lookup('profile::openstack::codfw1dev::neutron::mechanism_drivers', {default_value => ['linuxbridge', 'openvswitch', 'l2population']}),
) {
    class {'::profile::openstack::base::neutron::common':
        version                     => $version,
        openstack_control_nodes     => $openstack_control_nodes,
        haproxy_nodes               => $haproxy_nodes,
        rabbitmq_nodes              => $rabbitmq_nodes,
        keystone_api_fqdn           => $keystone_api_fqdn,
        db_pass                     => $db_pass,
        db_host                     => $db_host,
        region                      => $region,
        dhcp_domain                 => $dhcp_domain,
        ldap_user_pass              => $ldap_user_pass,
        rabbit_pass                 => $rabbit_pass,
        agent_down_time             => $agent_down_time,
        log_agent_heartbeats        => $log_agent_heartbeats,
        bind_port                   => $bind_port,
        enforce_policy_scope        => $enforce_policy_scope,
        enforce_new_policy_defaults => $enforce_new_policy_defaults,
        type_drivers                => $type_drivers,
        tenant_network_types        => $tenant_network_types,
        mechanism_drivers           => $mechanism_drivers,
    }
    contain '::profile::openstack::base::neutron::common'
}
