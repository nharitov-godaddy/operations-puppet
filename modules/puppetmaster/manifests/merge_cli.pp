# SPDX-License-Identifier: Apache-2.0
# @summary provisions the puppet-merge cli tools used in production to
# merge puppet commits
class puppetmaster::merge_cli (
    Hash[String, Puppetmaster::Backends] $servers,
    Stdlib::Host                         $ca_server,
    Wmflib::Ensure                       $ensure  = present,
) {
    # TODO: migrate to merge_cli module
    $masters = $servers.keys().filter |$server| { $server != $facts['fqdn'] }
    $workers = $servers.values().map |$worker| {
        $worker.map |$name| { $name['worker'] }.filter |$name| { $name != $facts['fqdn'] }
    }.flatten()
    $puppet_merge_conf = @("CONF")
    # Generated by Puppet
    MASTERS="${masters.join(' ')}"
    WORKERS="${workers.join(' ')}"
    CA_SERVER="${ca_server}"
    | CONF

    file { '/etc/puppet-merge.conf':
        ensure  => stdlib::ensure($ensure, 'file'),
        owner   => 'root',
        group   => 'root',
        mode    => '0555',
        content => $puppet_merge_conf,
    }

    file { '/usr/local/bin/puppet-merge':
        ensure => stdlib::ensure($ensure, 'file'),
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        source => 'puppet:///modules/merge_cli/puppet-merge.sh',
    }

    file { '/usr/local/bin/puppet-merge.py':
        ensure => stdlib::ensure($ensure, 'file'),
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        source => 'puppet:///modules/merge_cli/puppet-merge.py',
    }
}
