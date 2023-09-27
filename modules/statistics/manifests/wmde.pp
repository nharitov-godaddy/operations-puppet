# Licence AGPL version 3 or later
#
# Class for running WMDE releated statistics & analytics scripts.
#
# @author Addshore
class statistics::wmde(
    $statsd_host,
    $graphite_host,
    $wmde_secrets,
    $user  = 'analytics-wmde'
) {

    # The statistics module needs to be loaded before this one
    Class['::statistics'] -> Class['::statistics::wmde']

    $statistics_working_path = $::statistics::working_path

    $homedir = "${statistics_working_path}/analytics-wmde"

    # Scripts & systemd timers that generate data for graphite
    class { '::statistics::wmde::graphite':
        dir           => "${homedir}/graphite",
        user          => $user,
        statsd_host   => $statsd_host,
        graphite_host => $graphite_host,
        wmde_secrets  => $wmde_secrets,
        require       => User[$user],
    }

    # Wikidata concepts processing
    class { '::statistics::wmde::wdcm':
        dir     => "${homedir}/wdcm",
        user    => $user,
        require => User[$user],
    }

}
