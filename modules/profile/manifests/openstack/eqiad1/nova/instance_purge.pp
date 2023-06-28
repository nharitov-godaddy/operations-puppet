# SPDX-License-Identifier: Apache-2.0
class profile::openstack::eqiad1::nova::instance_purge(
    Array[Stdlib::Fqdn] $openstack_controllers = lookup('profile::openstack::eqiad1::openstack_controllers'),
    Array[Hash]         $purge_projects        = lookup('profile::openstack::eqiad1::purge_projects'),
    ) {

    # systemd::timer::job does not take a boolean
    if ($::facts['networking']['hostname'] == $openstack_controllers[0].split('\.')[0]) {
        $ensure = 'present'
    }
    else {
        $ensure = 'absent'
    }

    # We only want this running in one place; just pick the first
    #  option in the list.
    $purge_projects.each |Hash $purge_rules| {
        systemd::timer::job { "purge_project_instances_${purge_rules['project']}":
            ensure             => $ensure,
            description        => "Delete VMs older than ${purge_rules['days_to_delete']} days",
            interval           => {
                'start'    => 'OnCalendar',
                'interval' => '*-*-* 14:00:00', # Daily at 14:00 UTC
            },
            command            => "/usr/local/sbin/wmcs-instancepurge --project ${purge_rules['project']} --days-to-delete ${purge_rules['days_to_delete']} --days-to-nag ${purge_rules['days_to_nag']}",
            logging_enabled    => false,
            monitoring_enabled => false,
            user               => 'root',
            require            => File['/usr/local/sbin/wmcs-instancepurge'],
        }
    }

    systemd::timer::job { 'purge_vm_rbd_images':
        ensure      => $ensure,
        description => 'Clean up ceph images for deleted VMs. T289623',
        interval    => {
            'start'    => 'OnCalendar',
            'interval' => '*-*-* 04:00:00', # Daily at 04:00 UTC
        },
        command     => '/usr/local/sbin/wmcs-novastats-cephleaks --delete',
        user        => 'root',
        require     => File['/usr/local/sbin/wmcs-novastats-cephleaks'],
    }
}
