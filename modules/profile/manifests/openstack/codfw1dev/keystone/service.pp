class profile::openstack::codfw1dev::keystone::service(
    $version = hiera('profile::openstack::codfw1dev::version'),
    $region = hiera('profile::openstack::codfw1dev::region'),
    Array[Stdlib::Fqdn] $openstack_controllers = lookup('profile::openstack::codfw1dev::openstack_controllers'),
    $osm_host = hiera('profile::openstack::codfw1dev::osm_host'),
    $db_host = hiera('profile::openstack::codfw1dev::keystone::db_host'),
    $token_driver = hiera('profile::openstack::codfw1dev::keystone::token_driver'),
    $db_pass = hiera('profile::openstack::codfw1dev::keystone::db_pass'),
    $nova_db_pass = hiera('profile::openstack::codfw1dev::nova::db_pass'),
    $ldap_hosts = hiera('profile::openstack::codfw1dev::ldap_hosts'),
    $ldap_user_pass = hiera('profile::openstack::codfw1dev::ldap_user_pass'),
    $wiki_status_consumer_token = hiera('profile::openstack::codfw1dev::keystone::wiki_status_consumer_token'),
    $wiki_status_consumer_secret = hiera('profile::openstack::codfw1dev::keystone::wiki_status_consumer_secret'),
    $wiki_status_access_token = hiera('profile::openstack::codfw1dev::keystone::wiki_status_access_token'),
    $wiki_status_access_secret = hiera('profile::openstack::codfw1dev::keystone::wiki_status_access_secret'),
    $wiki_consumer_token = hiera('profile::openstack::codfw1dev::keystone::wiki_consumer_token'),
    $wiki_consumer_secret = hiera('profile::openstack::codfw1dev::keystone::wiki_consumer_secret'),
    $wiki_access_token = hiera('profile::openstack::codfw1dev::keystone::wiki_access_token'),
    $wiki_access_secret = hiera('profile::openstack::codfw1dev::keystone::wiki_access_secret'),
    $labs_hosts_range = hiera('profile::openstack::codfw1dev::labs_hosts_range'),
    $labs_hosts_range_v6 = hiera('profile::openstack::codfw1dev::labs_hosts_range_v6'),
    Array[Stdlib::Fqdn] $designate_hosts = lookup('profile::openstack::codfw1dev::designate_hosts'),
    $labweb_hosts = hiera('profile::openstack::codfw1dev::labweb_hosts'),
    $puppetmaster_hostname = hiera('profile::openstack::codfw1dev::puppetmaster_hostname'),
    $auth_port = hiera('profile::openstack::base::keystone::auth_port'),
    $public_port = hiera('profile::openstack::base::keystone::public_port'),
    Boolean $daemon_active = lookup('profile::openstack::codfw1dev::keystone::daemon_active'),
    String $wsgi_server = lookup('profile::openstack::codfw1dev::keystone::wsgi_server'),
    Stdlib::IP::Address::V4::CIDR $instance_ip_range = lookup('profile::openstack::codfw1dev::keystone::instance_ip_range', {default_value => '0.0.0.0/0'}),
    String $wmcloud_domain_owner = lookup('profile::openstack::codfw1dev::keystone::wmcloud_domain_owner'),
    String $bastion_project_id = lookup('profile::openstack::codfw1dev::keystone::bastion_project_id'),
    ) {

    class {'::profile::openstack::base::keystone::service':
        daemon_active               => $daemon_active,
        version                     => $version,
        region                      => $region,
        openstack_controllers       => $openstack_controllers,
        osm_host                    => $osm_host,
        db_host                     => $db_host,
        token_driver                => $token_driver,
        db_pass                     => $db_pass,
        nova_db_pass                => $nova_db_pass,
        ldap_hosts                  => $ldap_hosts,
        ldap_user_pass              => $ldap_user_pass,
        wiki_status_consumer_token  => $wiki_status_consumer_token,
        wiki_status_consumer_secret => $wiki_status_consumer_secret,
        wiki_status_access_token    => $wiki_status_access_token,
        wiki_status_access_secret   => $wiki_status_access_secret,
        wiki_consumer_token         => $wiki_consumer_token,
        wiki_consumer_secret        => $wiki_consumer_secret,
        wiki_access_token           => $wiki_access_token,
        wiki_access_secret          => $wiki_access_secret,
        labs_hosts_range            => $labs_hosts_range,
        labs_hosts_range_v6         => $labs_hosts_range_v6,
        designate_hosts             => $designate_hosts,
        labweb_hosts                => $labweb_hosts,
        wsgi_server                 => $wsgi_server,
        instance_ip_range           => $instance_ip_range,
        wmcloud_domain_owner        => $wmcloud_domain_owner,
        bastion_project_id          => $bastion_project_id,
    }
    contain '::profile::openstack::base::keystone::service'

    class {'::profile::openstack::base::keystone::hooks':
        version     => $version,
        wsgi_server => $wsgi_server,
    }
    contain '::profile::openstack::base::keystone::hooks'

    class {'::openstack::keystone::monitor::services':
        active      => true,
        auth_port   => $auth_port,
        public_port => $public_port,
    }
    contain '::openstack::keystone::monitor::services'
}
