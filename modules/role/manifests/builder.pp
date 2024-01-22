class role::builder {

    include profile::base::production
    include profile::firewall
    include profile::package_builder
    include profile::docker::engine
    include profile::docker::builder
    include profile::docker::ferm
    include profile::docker::reporter
    include profile::docker::prune
    include profile::systemtap::devserver
    include profile::java
}
