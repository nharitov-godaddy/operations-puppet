# == Class profile::analytics::refinery::job::data_check
#
# Configures systemd timer jobs that:
# - alert and send email about the faultyness of webrequest data.
# - alert if REFINE_FAILED flags are found in various datasources.
#
class profile::analytics::refinery::job::data_check (
    $use_kerberos  = lookup('profile::analytics::refinery::job::data_check::use_kerberos', { 'default_value' => false }),
    $ensure_timers = lookup('profile::analytics::refinery::job::data_check::ensure_timers', { 'default_value' => 'present' }),
) {
    require ::profile::analytics::refinery

    # This should not be hardcoded.  Instead, one should be able to use
    # $::cdh::hadoop::mount::mount_point to reference the user supplied
    # parameter when the cdh::hadoop::mount class is evaluated.
    # I am not sure why this is not working.
    $hdfs_mount_point = '/mnt/hdfs'

    # Since the 'stats' user is not in ldap, it is unnecessarily hard
    # to grant it access to the private data in hdfs. As discussed in
    #   https://gerrit.wikimedia.org/r/#/c/186254
    # the cron was used to run as hdfs instead, and now the systemd units
    # that are run by the timers below do the same.
    kerberos::systemd_timer { 'check_webrequest_partitions':
        ensure       => $ensure_timers,
        description  => 'Check HDFS Webrequest partitions',
        command      => "${::profile::analytics::refinery::path}/bin/refinery-dump-status-webrequest-partitions --hdfs-mount ${hdfs_mount_point} --datasets webrequest,raw_webrequest --quiet --percent-lost",
        interval     => '*-*-* 10:00:00',
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }

    kerberos::systemd_timer { 'check_pageviews_partitions':
        ensure       => $ensure_timers,
        description  => 'Check HDFS Pageviews partitions',
        command      => "${::profile::analytics::refinery::path}/bin/refinery-dump-status-webrequest-partitions --hdfs-mount ${hdfs_mount_point} --datasets pageview,projectview --quiet",
        interval     => '*-*-* 10:10:00',
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }

    profile::analytics::refinery::job::refine_job { 'failed_flags_eventlogging_analytics':
        job_class              => 'org.wikimedia.analytics.refinery.job.refine.RefineFailuresChecker',
        refine_monitor_enabled => false,
        job_config             => {
            'input_path'                      => '/wmf/data/raw/eventlogging',
            'input_path_regex'                => 'eventlogging_(.+)/hourly/(.+)/(.+)/(.+)/(.+)',
            'output_path'                     => '/wmf/data/event',
            'input_path_regex_capture_groups' => 'table,year,month,day,hour',
            'database'                        => 'event',
        },
        spark_driver_memory    => '4G',
        spark_extra_opts       => '--deploy-mode client',
        interval               => '*-*-* 00:00:00',
        use_kerberos           => $use_kerberos,
    }
}