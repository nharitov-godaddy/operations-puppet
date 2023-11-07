# SPDX-License-Identifier: Apache-2.0
# openldap server
class profile::openldap (
    $hostname = lookup('profile::openldap::hostname'),
    $mirror_mode = lookup('profile::openldap::mirror_mode'),
    $backup = lookup('profile::openldap::backup'),
    $sync_pass = lookup('profile::openldap::sync_pass'),
    $master = lookup('profile::openldap::master'),
    $server_id = lookup('profile::openldap::server_id'),
    $hash_passwords = lookup('profile::openldap::hash_passwords'),
    $read_only = lookup('profile::openldap::read_only'),
    $certname = lookup('profile::openldap::certname'),
    $storage_backend = lookup('profile::openldap::storage_backend'),
    Array[OpenStack::ControlNode] $openstack_control_nodes = lookup('profile::openstack::eqiad1::openstack_control_nodes'),
    Integer             $size_limit = lookup('profile::openldap::size_limit'),
){
    # Certificate needs to be readable by slapd
    acme_chief::cert { $certname:
        puppet_svc => 'slapd',
        key_group  => 'openldap',
    }

    $suffix = 'dc=wikimedia,dc=org'

    $epp_params = {
        'suffix'             => $suffix,
        'cloudcontrol_hosts' => $openstack_control_nodes.map |OpenStack::ControlNode $node| { $node['host_fqdn'] },
    }

    class { '::openldap':
        server_id       => $server_id,
        sync_pass       => $sync_pass,
        suffix          => $suffix,
        datadir         => '/var/lib/ldap/labs',
        ca              => '/etc/ssl/certs/ca-certificates.crt',
        certificate     => "/etc/acmecerts/${certname}/live/rsa-2048.chained.crt",
        key             => "/etc/acmecerts/${certname}/live/rsa-2048.key",
        extra_schemas   => ['dnsdomain2.schema', 'nova_sun.schema', 'openssh-ldap.schema',
                            'puppet.schema', 'sudo.schema', 'wmf-user.schema'],
        extra_indices   => 'openldap/main-indices.erb',
        extra_acls      => epp('openldap/main-acls.epp', $epp_params),
        mirrormode      => $mirror_mode,
        master          => $master,
        hash_passwords  => $hash_passwords,
        read_only       => $read_only,
        size_limit      => $size_limit,
        storage_backend => $storage_backend,
    }

    # Ldap services are used all over the place, including within
    # WMCS and on various prod hosts.
    ferm::service { 'ldap':
        proto  => 'tcp',
        port   => [389, 636],
        srange => '($PRODUCTION_NETWORKS $LABS_NETWORKS)',
    }

    $monitoring_rw_desc = $read_only.bool2str('read-only', 'writable')
    monitoring::service { 'ldap':
        description   => "LDAP (${monitoring_rw_desc} server)",
        check_command => 'check_ldap!dc=wikimedia,dc=org',
        critical      => false,
        notes_url     => 'https://wikitech.wikimedia.org/wiki/LDAP#Troubleshooting',
    }

    if $backup {
        backup::openldapset { 'openldap': }
    }

    include profile::openldap::restarts
}
