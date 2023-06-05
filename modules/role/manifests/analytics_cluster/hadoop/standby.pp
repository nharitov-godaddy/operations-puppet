# == Class role::analytics_cluster::hadoop::standby
# Include standby NameNode classes
#
class role::analytics_cluster::hadoop::standby {
    system::role { 'analytics_cluster::hadoop::standby':
        description => 'Hadoop Standby NameNode',
    }

    include ::profile::java
    include ::profile::hadoop::common
    include ::profile::hadoop::master::standby
    include ::profile::analytics::cluster::hadoop::yarn_capacity_scheduler
    include ::profile::hadoop::firewall::master
    # This is a Hadoop client, and should
    # have any service system users it needs to
    # interacting with HDFS.
    include ::profile::analytics::cluster::users
    include ::profile::hadoop::backup::namenode
    include ::profile::kerberos::client
    include ::profile::kerberos::keytabs
    include ::profile::firewall
    include ::profile::base::production

}
