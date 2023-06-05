# SPDX-License-Identifier: Apache-2.0
class role::wmcs::openstack::eqiad1::rabbitmq {
    system::role { 'wmcs::openstack::eqiad1::rabbitmq':
        description => 'WMCS Rabbit message queue host',
    }

    include profile::base::production
    include profile::firewall
    include profile::base::cloud_production

    include profile::openstack::eqiad1::rabbitmq
}
