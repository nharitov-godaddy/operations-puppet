class role::wmcs::toolforge::elastic7 {
    system::role { $name: }
    include ::profile::firewall
    include ::profile::toolforge::base
    include ::profile::toolforge::apt_pinning
    include ::profile::elasticsearch::toolforge
    include ::profile::toolforge::elasticsearch::haproxy
    include ::profile::toolforge::elasticsearch::keepalived
    include ::profile::prometheus::haproxy_exporter
}
