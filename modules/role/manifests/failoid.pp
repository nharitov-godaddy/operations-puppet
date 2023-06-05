# == Class: role::failoid
# A simple service that reject any connections to a list of ports.
class role::failoid {

    system::role { 'failoid': description => 'Failoid service' }

    include ::profile::base::production
    include ::profile::firewall
    include ::profile::failoid
}
