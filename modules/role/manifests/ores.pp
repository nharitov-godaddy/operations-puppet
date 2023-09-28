# ORES
class role::ores {

    system::role { 'ores':
        description => 'ORES service'
    }

    include ::profile::base::production
    include ::profile::firewall

    include ::profile::ores::git
    include ::profile::ores::worker
    include ::profile::ores::web
    include ::profile::tlsproxy::envoy # TLS termination
    include ::profile::services_proxy::envoy # RPC proxy
}
