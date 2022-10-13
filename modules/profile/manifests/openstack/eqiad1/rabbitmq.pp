class profile::openstack::eqiad1::rabbitmq(
    Array[Stdlib::Fqdn] $openstack_controllers = lookup('profile::openstack::eqiad1::openstack_controllers'),
    Array[Stdlib::Fqdn] $rabbitmq_nodes = lookup('profile::openstack::eqiad1::rabbitmq_nodes'),
    Array[Stdlib::Fqdn] $rabbitmq_setup_nodes = lookup('profile::openstack::eqiad1::rabbitmq_setup_nodes'),
    $monitor_user = lookup('profile::openstack::eqiad1::rabbit_monitor_user'),
    $monitor_password = lookup('profile::openstack::eqiad1::rabbit_monitor_pass'),
    $cleanup_password = lookup('profile::openstack::eqiad1::rabbit_cleanup_pass'),
    $file_handles = lookup('profile::openstack::eqiad1::rabbit_file_handles'),
    Array[Stdlib::Fqdn] $designate_hosts = lookup('profile::openstack::eqiad1::designate_hosts'),
    String $nova_rabbit_user = lookup('profile::openstack::base::nova::rabbit_user'),
    String $nova_rabbit_password = lookup('profile::openstack::eqiad1::nova::rabbit_pass'),
    String $neutron_rabbit_user = lookup('profile::openstack::base::neutron::rabbit_user'),
    String $neutron_rabbit_password = lookup('profile::openstack::eqiad1::neutron::rabbit_pass'),
    String $heat_rabbit_user = lookup('profile::openstack::base::heat::rabbit_user'),
    String $heat_rabbit_password = lookup('profile::openstack::eqiad1::heat::rabbit_pass'),
    String $trove_guest_rabbit_user = lookup('profile::openstack::base::trove::trove_guest_rabbit_user'),
    String $trove_guest_rabbit_pass = lookup('profile::openstack::eqiad1::trove::trove_guest_rabbit_pass'),
    Optional[String] $rabbit_cfssl_label = lookup('profile::openstack::codfw1dev::rabbitmq::rabbit_cfssl_label', {default_value => undef}),
    $rabbit_erlang_cookie = lookup('profile::openstack::eqiad1::rabbit_erlang_cookie'),
    Array[Stdlib::Fqdn] $cinder_backup_nodes = lookup('profile::openstack::eqiad1::cinder::backup::nodes'),
    Integer $heartbeat_timeout = lookup('profile::openstack::eqiad1::rabbitmq_heartbeat_timeout'),
){

    require ::profile::openstack::eqiad1::clientpackages
    class {'::profile::openstack::base::rabbitmq':
        openstack_controllers   => $openstack_controllers,
        rabbitmq_nodes          => $rabbitmq_nodes,
        rabbitmq_setup_nodes    => $rabbitmq_setup_nodes,
        monitor_user            => $monitor_user,
        monitor_password        => $monitor_password,
        cleanup_password        => $cleanup_password,
        file_handles            => $file_handles,
        designate_hosts         => $designate_hosts,
        nova_rabbit_user        => $nova_rabbit_user,
        nova_rabbit_password    => $nova_rabbit_password,
        neutron_rabbit_user     => $neutron_rabbit_user,
        neutron_rabbit_password => $neutron_rabbit_password,
        heat_rabbit_user        => $heat_rabbit_user,
        heat_rabbit_password    => $heat_rabbit_password,
        trove_guest_rabbit_user => $trove_guest_rabbit_user,
        trove_guest_rabbit_pass => $trove_guest_rabbit_pass,
        rabbit_erlang_cookie    => $rabbit_erlang_cookie,
        rabbit_cfssl_label      => $rabbit_cfssl_label,
        cinder_backup_nodes     => $cinder_backup_nodes,
        heartbeat_timeout       => $heartbeat_timeout,
    }
    contain '::profile::openstack::base::rabbitmq'
}
