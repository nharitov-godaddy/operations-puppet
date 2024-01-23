class role::ml_k8s::staging::master {
    include profile::base::production
    include profile::firewall

    # Sets up kubernetes on the machine
    include profile::kubernetes::master

    # Needed to schedule containers like bird, used by calico.
    # More info: T285927
    # Sets up docker on the machine.
    include profile::docker::engine
    include profile::kubernetes::node
    include profile::calico::kubernetes

    # LVS configuration (VIP)
    include profile::lvs::realserver
}
