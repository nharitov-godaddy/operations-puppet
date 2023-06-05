class role::wmcs::db::wikireplicas::dedicated::analytics_multiinstance {
    system::role { $name:
        description => 'wikireplica database - analytics, multi-instance (Analytics team\'s special db host)',
    }

    include profile::base::production
    include profile::wmcs::db::wikireplicas::mariadb_multiinstance
    include profile::firewall
    include profile::base::cloud_production
    include profile::wmcs::db::wikireplicas::views
    include profile::mariadb::check_private_data
    include profile::wmcs::db::wikireplicas::dedicated::analytics
}
