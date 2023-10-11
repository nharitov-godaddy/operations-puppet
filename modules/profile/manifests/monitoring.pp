# @summary profile to configure icinga monitoring host
#   Sets up base Nagios monitoring for the host.  This includes
#   - ping
#   - ssh
#   - dpkg
#   - disk space
#   - raid
#   - ipmi
#
#   Note that this class is probably already included for your node
#   by the class base.  If you want to change the contact_group, set
#   the variable contactgroups in hiera.
#   class base will use this variable as the $contact_group argument
#   when it includes this class.
#
# @param hardware_monitoring indicate if we should monitor HW
# @param contact_group Nagios contact_group to use for notifications.
# @param cluster the cluster to ack on
# @param is_critical indicate this host is critical
# @param monitor_systemd indicate if we should monitor systemd
# @param nrpe_check_disk_options Default options for checking disks.  Defaults to checking
#   all disks and warning at < 6% and critical at < 3% free.
# @param raid_check indicate if we should check raid
# @param nrpe_check_disk_critical Make disk space alerts paging, defaults to not paging
# @param raid_check_interval check interval for raid checks
# @param raid_retry_interval retry interval for raid retries
# @param notifications_enabled indicate if we should send notifications
# @param do_paging if true send pages
# @param nagios_group The nagios group to use for notifications
# @param services A hash of services to monitor on all servers
# @param hosts The hosts to monitor
# @param monitoring_hosts The monitoring hosts used in FW rules
# @param raid_write_cache_policy The raid policy to use for checks
class profile::monitoring (
    Wmflib::Ensure      $hardware_monitoring        = lookup('profile::monitoring::hardware_monitoring'),
    # TODO: make this an array
    String              $contact_group              = lookup('profile::monitoring::contact_group'),
    String              $cluster                    = lookup('profile::monitoring::cluster'),
    Boolean             $is_critical                = lookup('profile::monitoring::is_critical'),
    Boolean             $monitor_systemd            = lookup('profile::monitoring::monitor_systemd'),
    String              $nrpe_check_disk_options    = lookup('profile::monitoring::nrpe_check_disk_options'),
    Boolean             $nrpe_check_disk_critical   = lookup('profile::monitoring::nrpe_check_disk_critical'),
    Boolean             $raid_check                 = lookup('profile::monitoring::raid_check'),
    Integer             $raid_check_interval        = lookup('profile::monitoring::raid_check_interval'),
    Integer             $raid_retry_interval        = lookup('profile::monitoring::raid_retry_interval'),
    Boolean             $notifications_enabled      = lookup('profile::monitoring::notifications_enabled'),
    Boolean             $do_paging                  = lookup('profile::monitoring::do_paging'),
    String              $nagios_group               = lookup('profile::monitoring::nagios_group'),
    Hash                $services                   = lookup('profile::monitoring::services'),
    Hash                $hosts                      = lookup('profile::monitoring::hosts'),
    Array[Stdlib::Host] $monitoring_hosts           = lookup('profile::monitoring::monitoring_hosts'),
    Optional[Enum['WriteThrough', 'WriteBack']] $raid_write_cache_policy = lookup('profile::monitoring::raid_write_cache_policy')
) {
    include profile::puppet::agent
    $puppet_interval = $profile::puppet::agent::interval

    if $raid_check and $hardware_monitoring == 'present' {
        # RAID checks
        class { 'raid':
            write_cache_policy => $raid_write_cache_policy,
            check_interval     => $raid_check_interval,
            retry_interval     => $raid_retry_interval,
        }
    }

    class { 'monitoring':
        contact_group         => $contact_group,
        nagios_group          => $nagios_group,
        cluster               => $cluster,
        notifications_enabled => $notifications_enabled,
        do_paging             => $do_paging,
        hosts                 => $hosts,
        services              => $services,
    }

    class { 'nrpe':
        allowed_hosts => $monitoring_hosts.join(','),
    }
    # the nrpe class installs monitoring-plugins-* which creates the following directory
    contain nrpe  # lint:ignore:wmf_styleguide

    nrpe::plugin { 'check_puppetrun':
        source => 'puppet:///modules/profile/monitoring/check_puppetrun.rb',
    }

    nrpe::plugin { 'check_eth':
        content => template('profile/monitoring/check_eth.erb'),
    }

    nrpe::plugin { 'check_sysctl':
        source => 'puppet:///modules/profile/monitoring/check_sysctl',
    }

    nrpe::plugin { 'check_established_connections':
        source => 'puppet:///modules/profile/monitoring/check_established_connections.sh',
    }

    nrpe::plugin { 'check_fresh_files_in_dir':
        source => 'puppet:///modules/profile/monitoring/check_fresh_files_in_dir.py',
    }

    nrpe::plugin { 'check_newest_file_age':
        source => 'puppet:///modules/profile/monitoring/check_newest_file_age.sh',
    }

    file { [
        '/usr/lib/nagios/plugins/check_sysctl',
        '/usr/lib/nagios/plugins/check_established_connections',
        '/usr/lib/nagios/plugins/check-fresh-files-in-dir.py',
    ]:
        ensure => absent,
    }

    nrpe::monitor_service { 'disk_space':
        description     => 'Disk space',
        critical        => $nrpe_check_disk_critical,
        nrpe_command    => "/usr/lib/nagios/plugins/check_disk ${nrpe_check_disk_options}",
        notes_url       => 'https://wikitech.wikimedia.org/wiki/Monitoring/Disk_space',
        dashboard_links => ["https://grafana.wikimedia.org/d/000000377/host-overview?var-server=${facts['hostname']}&var-datasource=${::site} prometheus/ops"],
        check_interval  => 20,
        retry_interval  => 5,
    }

    # Calculate freshness interval in seconds (hence *60)
    $warninginterval = $puppet_interval * 60 * 6
    $criticalinterval = $warninginterval * 2

    sudo::user { 'nagios_puppetrun':
        ensure => absent,
    }

    nrpe::monitor_service { 'puppet_checkpuppetrun':
        description    => 'puppet last run',
        nrpe_command   => "/usr/local/lib/nagios/plugins/check_puppetrun -w ${warninginterval} -c ${criticalinterval}",
        sudo_user      => 'root',
        check_interval => 5,
        retry_interval => 1,
        notes_url      => 'https://wikitech.wikimedia.org/wiki/Monitoring/puppet_checkpuppetrun',
    }
    nrpe::monitor_service { 'check_eth':
        description    => 'configured eth',
        nrpe_command   => '/usr/local/lib/nagios/plugins/check_eth',
        notes_url      => 'https://wikitech.wikimedia.org/wiki/Monitoring/check_eth',
        check_interval => 30,
    }

    $ensure_monitor_systemd = $monitor_systemd.bool2str('present','absent')

    nrpe::plugin { 'check_systemd_state':
        ensure => $ensure_monitor_systemd,
        source => 'puppet:///modules/profile/monitoring/check_systemd_state.py',
    }

    nrpe::monitor_service { 'check_systemd_state':
        ensure       => $ensure_monitor_systemd,
        description  => 'Check systemd state',
        nrpe_command => '/usr/local/lib/nagios/plugins/check_systemd_state',
        notes_url    => 'https://wikitech.wikimedia.org/wiki/Monitoring/check_systemd_state',
    }

    if ! $facts['is_virtual'] {
        include profile::prometheus::nic_saturation_exporter
        class { 'prometheus::node_nic_firmware': }
        if $facts['processors']['models'][0] !~ /AMD/ {
            class { 'prometheus::node_intel_microcode': }
        }
    }

    if $facts['has_ipmi'] {
        class { 'ipmi::monitor': ensure => $hardware_monitoring }
    }

    # TODO: remove absented resource
    # https://phabricator.wikimedia.org/T239862
    host { 'statsd.eqiad.wmnet':
        ensure       => absent,
        ip           => '10.64.16.81', # graphite1005
        host_aliases => 'statsd',
    }
}
