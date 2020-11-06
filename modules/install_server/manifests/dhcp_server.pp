# Class: install_server::dhcp_server
#
# This class installs isc-dhcp-server and configures it
#
# Parameters:
#
# Actions:
#       Install isc-dhcp-server and populate configuration directory
#
# Requires:
#
# Sample Usage:
#   include install_server::dhcp_server

class install_server::dhcp_server (
    Stdlib::Ensure::Service $ensure_service = 'running',
){
    file { '/etc/dhcp':
        ensure  => directory,
        require => Package['isc-dhcp-server'],
        recurse => true,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => 'puppet:///modules/install_server/dhcpd',
    }

    package { 'isc-dhcp-server':
        ensure => present,
    }

    service { 'isc-dhcp-server':
        ensure    => $ensure_service,
        require   => [
            Package['isc-dhcp-server'],
            File['/etc/dhcp']
        ],
        subscribe => File['/etc/dhcp'],
    }

    # TODO: Fold this into modules/install/dhcpd once
    # all jessie-based install servers are replaced.
    if debian::codename::ge('buster') {
        file_line { 'dhcpd_interfaces':
          ensure => present,
          path   => '/etc/default/isc-dhcp-server',
          line   => "INTERFACESv4=\"${facts['interface_primary']}\"  # Managed by puppet",
          match  => "INTERFACESv4=\"\"",
        }
    }
}
