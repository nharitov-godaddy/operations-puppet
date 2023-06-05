# == Class role::kafka::jumbo::broker
# Sets up a Kafka broker in the 'jumbo' Kafka cluster.
#
class role::kafka::jumbo::broker {
    system::role { 'role::kafka::jumbo::broker':
        description => "Kafka Broker in a 'jumbo' Kafka cluster",
    }

    include profile::firewall
    include profile::kafka::broker

    # Mirror main-eqiad -> jumbo-eqiad
    include profile::kafka::mirror

    include ::profile::base::production
}
