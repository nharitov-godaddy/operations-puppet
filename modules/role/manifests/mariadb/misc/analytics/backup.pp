class role::mariadb::misc::analytics::backup {

    system::role { 'mariadb::misc::analytics::backup':
        description => 'Backup Analytics Multiinstance Databases',
    }

    include ::profile::base::production
    include ::profile::firewall

    include ::profile::mariadb::misc::analytics::multiinstance
}
