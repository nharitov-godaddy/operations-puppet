# miscellaneous services clusters
class role::mariadb::misc {

    system::role { 'mariadb::misc':
        description => 'Misc DB Server',
    }

    include ::profile::base::production
    include ::profile::firewall
    include ::profile::mariadb::misc
}
