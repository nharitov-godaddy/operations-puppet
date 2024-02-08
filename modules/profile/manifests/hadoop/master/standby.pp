# SPDX-License-Identifier: Apache-2.0
# == Class profile::hadoop::master::standby
#
# Sets up a standby/backup Hadoop Master node.
#
#  [*monitoring_enabled*]
#    If production monitoring needs to be enabled or not.
#
class profile::hadoop::master::standby(
    $cluster_name             = lookup('profile::hadoop::common::hadoop_cluster_name'),
    $monitoring_enabled       = lookup('profile::hadoop::master::standby::monitoring_enabled', { 'default_value' => false }),
    $excluded_hosts           = lookup('profile::hadoop::master::standby::excluded_hosts', { 'default_value' => [] }),
) {
    require ::profile::hadoop::common

    if $monitoring_enabled {
        # Prometheus exporters
        require ::profile::hadoop::monitoring::namenode
        require ::profile::hadoop::monitoring::resourcemanager
    }

    class { '::bigtop::hadoop::namenode::standby':
        excluded_hosts => $excluded_hosts,
    }

    # Include icinga alerts if production realm.
    if $monitoring_enabled {
        # Icinga process alert for Stand By NameNode
        nrpe::monitor_service { 'hadoop-hdfs-namenode':
            description   => 'Hadoop Namenode - Stand By',
            nrpe_command  => '/usr/lib/nagios/plugins/check_procs -c 1:1 -C java -a "org.apache.hadoop.hdfs.server.namenode.NameNode"',
            contact_group => 'admins,team-data-platform',
            require       => Class['bigtop::hadoop::namenode::standby'],
            notes_url     => 'https://wikitech.wikimedia.org/wiki/Analytics/Systems/Cluster/Hadoop/Administration',
        }
        nrpe::monitor_service { 'hadoop-hdfs-zkfc':
            description   => 'Hadoop HDFS Zookeeper failover controller',
            nrpe_command  => '/usr/lib/nagios/plugins/check_procs -c 1:1 -C java -a "org.apache.hadoop.hdfs.tools.DFSZKFailoverController"',
            contact_group => 'admins,team-data-platform',
            require       => Class['bigtop::hadoop::namenode::standby'],
            notes_url     => 'https://wikitech.wikimedia.org/wiki/Analytics/Systems/Cluster/Hadoop/Administration',
        }
    }

    class { '::bigtop::hadoop::resourcemanager':
        excluded_hosts => $excluded_hosts,
    }

}
