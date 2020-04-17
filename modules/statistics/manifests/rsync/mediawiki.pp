# == Class statistics::rsync::mediawiki
#
# Sets up daily cron jobs to rsync log files from remote
# logging hosts to a local destination for further processing.
#
class statistics::rsync::mediawiki {
    Class['::statistics'] -> Class['::statistics::rsync::mediawiki']

    # Any logs older than this will be pruned by
    # the rsync_job define.
    $retention_days = 60

    $mw_log_dir = '/srv/log/mw-log'

    file { [$mw_log_dir, "${mw_log_dir}/archive", "${mw_log_dir}/archive/api"]:
        ensure  => 'directory',
        owner   => 'root',
        group   => 'analytics-privatedata-users',
        mode    => '0750',
        require => Group['analytics-privatedata-users'],
    }

    # MediaWiki API logs
    statistics::rsync_job { 'mw-api':
        source         => 'mwlog1001.eqiad.wmnet::udp2log/archive/api.log-*.gz',
        destination    => "${$mw_log_dir}/archive/api",
        # Retention of 30 days to save disk space
        retention_days => 30,
        cron_user      => 'root',
    }
}
