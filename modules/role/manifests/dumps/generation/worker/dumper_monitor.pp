class role::dumps::generation::worker::dumper_monitor {
    include profile::base::production
    include profile::firewall

    include profile::dumps::generation::worker::common
    include profile::dumps::generation::worker::dumper
    include profile::dumps::generation::worker::monitor

    system::role { 'snapshot::dumper_monitor':
        description => 'dumper of XML/SQL wiki content, monitor',
    }
}
