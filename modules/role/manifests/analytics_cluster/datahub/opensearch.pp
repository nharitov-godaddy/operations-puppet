class role::analytics_cluster::datahub::opensearch {
    system::role { 'analytics_cluster::datahub::opensearch':
        description => 'Opensearch cluster powering datahub'
    }

    include ::profile::base::production
    include ::profile::firewall
    include ::profile::opensearch::datahubsearch
    include ::profile::rsyslog::udp_json_logback_compat
    include ::profile::opensearch::monitoring::base_checks
    include ::profile::lvs::realserver
}
