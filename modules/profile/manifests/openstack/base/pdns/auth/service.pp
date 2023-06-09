class profile::openstack::base::pdns::auth::service(
    Array[Stdlib::Fqdn] $hosts = lookup('profile::openstack::base::pdns::hosts'),
    Stdlib::Fqdn $service_fqdn = lookup('profile::openstack::base::pdns::service_fqdn'),
    $db_host = lookup('profile::openstack::base::pdns::db_host'),
    $db_pass = lookup('profile::openstack::base::pdns::db_pass'),
    $pdns_webserver = lookup('profile::openstack::base::pdns::pdns_webserver', {'default_value' => false}),
    String $pdns_api_key = lookup('profile::openstack::base::pdns::pdns_api_key', {'default_value' => ''}),
    $pdns_api_allow_from = lookup('profile::openstack::base::pdns::pdns_api_allow_from', {'default_value' => ''}),
){

    class { '::pdns_server':
        listen_on            => [$facts['ipaddress'], $facts['ipaddress6']],
        query_source_address => $facts['ipaddress'],
        dns_auth_soa_name    => $service_fqdn,
        pdns_db_host         => $db_host,
        pdns_db_password     => $db_pass,
        dns_webserver        => $pdns_webserver,
        dns_api_key          => $pdns_api_key,
        dns_api_allow_from   => $pdns_api_allow_from,
    }

    ferm::service { 'udp_dns_rec':
        proto => 'udp',
        port  => '53',
    }

    ferm::service { 'tcp_dns_rec':
        proto => 'tcp',
        port  => '53',
    }

    ferm::rule { 'skip_dns_conntrack-out':
        desc  => 'Skip DNS outgoing connection tracking',
        table => 'raw',
        chain => 'OUTPUT',
        rule  => 'proto udp sport 53 NOTRACK;',
    }

    ferm::rule { 'skip_dns_conntrack-in':
        desc  => 'Skip DNS incoming connection tracking',
        table => 'raw',
        chain => 'PREROUTING',
        rule  => 'proto udp dport 53 NOTRACK;',
    }

    ::ferm::service { 'pdns-rest-api':
        proto  => 'tcp',
        port   => '8081',
        srange => "(@resolve((${join($hosts,' ')})) @resolve((${join($hosts,' ')}), AAAA))",
    }

}
