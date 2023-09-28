# SPDX-License-Identifier: Apache-2.0

class openstack::magnum::service::zed(
    String $db_user,
    String $region,
    Array[Stdlib::Fqdn] $memcached_nodes,
    Array[Stdlib::Fqdn] $rabbitmq_nodes,
    String $db_pass,
    String $db_name,
    Stdlib::Fqdn $db_host,
    Stdlib::Fqdn $etcd_discovery_host,
    String $ldap_user_pass,
    Stdlib::Fqdn $keystone_fqdn,
    Stdlib::Port $api_bind_port,
    String $rabbit_user,
    String $rabbit_pass,
    String $domain_admin_pass,
    Boolean $enforce_policy_scope,
    Boolean $enforce_new_policy_defaults,
) {
    require "openstack::serverpackages::zed::${::lsbdistcodename}"

    package { 'magnum-api':
        ensure => 'present',
    }
    package { 'magnum-conductor':
        ensure => 'present',
    }

    $version = inline_template("<%= @title.split(':')[-1] -%>")
    $keystone_auth_username = 'magnum'
    $keystone_auth_project = 'service'
    $etcd_discovery_url = "https://${etcd_discovery_host}"
    file {
        '/etc/magnum/magnum.conf':
            content   => template('openstack/zed/magnum/magnum.conf.erb'),
            owner     => 'magnum',
            group     => 'magnum',
            mode      => '0440',
            show_diff => false,
            notify    => Service['magnum-api', 'magnum-conductor'],
            require   => Package['magnum-api', 'magnum-conductor'];
        '/etc/magnum/policy.yaml':
            source  => 'puppet:///modules/openstack/zed/magnum/policy.yaml',
            owner   => 'root',
            group   => 'root',
            mode    => '0644',
            notify  => Service['magnum-api', 'magnum-conductor'],
            require => Package['magnum-api', 'magnum-conductor'];
        '/etc/init.d/magnum-api':
            content => template('openstack/zed/magnum/magnum-api.erb'),
            owner   => 'root',
            group   => 'root',
            mode    => '0755',
    }


    # Hack in fix for log size
    #  https://phabricator.wikimedia.org/T336586
    #  https://review.opendev.org/c/openstack/magnum/+/885900
    # These next two files can be removed once the upstream patch is merged and
    # we catch up with it.
    $fragment_file_to_patch = '/usr/lib/python3/dist-packages/magnum/drivers/common/templates/kubernetes/fragments/start-container-agent.sh'
    $fragment_patch_file = "${fragment_file_to_patch}.patch"
    file {$fragment_patch_file:
        source => 'puppet:///modules/openstack/zed/magnum/hacks/drivers/common/templates/kubernetes/fragments/start-container-agent.sh.patch',
        owner  => 'root',
        group  => 'root',
        mode   => '0644',
    }
    exec { "apply ${fragment_patch_file}":
        command => "/usr/bin/patch --forward ${fragment_file_to_patch} ${fragment_patch_file}",
        unless  => "/usr/bin/patch --reverse --dry-run -f ${fragment_file_to_patch} ${fragment_patch_file}",
        require => [File[$fragment_patch_file], Package['magnum-api']],
        notify  => Service['magnum-api'],
    }
    $template_file_to_patch = '/usr/lib/python3/dist-packages/magnum/drivers/k8s_fedora_coreos_v1/templates/fcct-config.yaml'
    $template_patch_file = "${template_file_to_patch}.patch"
    file {$template_patch_file:
        source => 'puppet:///modules/openstack/zed/magnum/hacks/drivers/k8s_fedora_coreos_v1/templates/fcct-config.yaml.patch',
        owner  => 'root',
        group  => 'root',
        mode   => '0644',
    }
    exec { "apply ${template_patch_file}":
        command => "/usr/bin/patch --forward ${template_file_to_patch} ${template_patch_file}",
        unless  => "/usr/bin/patch --reverse --dry-run -f ${template_file_to_patch} ${template_patch_file}",
        require => [File[$template_patch_file], Package['magnum-api']],
        notify  => Service['magnum-api'],
    }



}
