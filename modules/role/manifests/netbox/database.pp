# Class: role::netbox::database
#
# This role installs all the Netbox database related parts as WMF requires it
#
# Actions:
#       Deploy Netbox database server
#
# Requires:
#
# Sample Usage:
#       role(netbox::database)
#

class role::netbox::database {
    include profile::base::production

    system::role { 'netbox::database': description => 'Netbox database server' }

    include profile::netbox::db
    include profile::prometheus::postgres_exporter
    include profile::firewall
    # Fixme consider adding this later
    # include ::profile::backup::host
}
