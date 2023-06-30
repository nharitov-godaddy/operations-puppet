# SPDX-License-Identifier: Apache-2.0
class profile::openstack::codfw1dev::pdns::auth::service(
    Array[Stdlib::Fqdn] $hosts = lookup('profile::openstack::codfw1dev::pdns::hosts'),
    Array[Stdlib::Fqdn] $designate_hosts = lookup('profile::openstack::codfw1dev::designate_hosts'),
    Array[Stdlib::Fqdn] $prometheus_nodes = lookup('prometheus_nodes'),
    $db_pass = lookup('profile::openstack::codfw1dev::pdns::db_pass'),
    String $pdns_api_key = lookup('profile::openstack::codfw1dev::pdns::api_key'),
) {
    $api_allow_hosts = flatten([$hosts, $prometheus_nodes, $designate_hosts])

    # We're patching in our ipv4 address for db_host here;
    #  for unclear reasons 'localhost' doesn't work properly
    #  with the version of Mariadb installed on Jessie.
    class {'::profile::openstack::base::pdns::auth::service':
        hosts               => $hosts,
        designate_hosts     => $designate_hosts,
        db_pass             => $db_pass,
        db_host             => ipresolve($::fqdn,4),
        pdns_webserver      => true,
        pdns_api_key        => $pdns_api_key,
        pdns_api_allow_from => flatten([
            '127.0.0.1',
            $api_allow_hosts.map |Stdlib::Fqdn $host| { ipresolve($host, 4) }
        ]),
    }
}
