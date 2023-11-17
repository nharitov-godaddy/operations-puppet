# SPDX-License-Identifier: Apache-2.0
# @summary configures a directory to be rsynced from the primary puppetserver to all others
define puppetserver::rsync_module (
    Stdlib::Unixpath         $path,
    Array[Stdlib::Fqdn]      $hosts,
    Systemd::Timer::Schedule $interval,
) {
    $ca_server = $puppetserver::ca_server
    $is_ca = $ca_server == $facts['networking']['fqdn']
    $other_hosts = $hosts - $facts['networking']['fqdn']
    $server_ensure = stdlib::ensure($is_ca and !$other_hosts.empty())

    if !$is_ca and !($facts['networking']['fqdn'] in $hosts) {
        fail("${title}: current host is not active CA server or in list of targets")
    }

    rsync::server::module { "puppet_${title}":
        ensure      => $server_ensure,
        read_only   => 'yes',
        hosts_allow => $other_hosts,
        chroot      => false,
        path        => $path,
    }

    systemd::timer::job { "sync-puppet-${title}":
        ensure             => stdlib::ensure(!$is_ca),
        user               => 'root',
        description        => "rsync puppet ${title} data from primary server",
        command            => "/usr/bin/rsync -avz --delete ${ca_server}::puppet_${title} ${path}",
        interval           => $interval,
        monitoring_enabled => false,
        logging_enabled    => false,
    }

    firewall::service { "puppet-rsync-${title}":
        ensure => $server_ensure,
        proto  => 'tcp',
        port   => [873],
        srange => $other_hosts,
    }
}
