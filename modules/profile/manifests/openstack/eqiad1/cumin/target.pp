# SPDX-License-Identifier: Apache-2.0
# @summary
# Profile to allow a Cumin master for WMCS or a specific Cloud VPS project to
# connect to this Cloud VPS instance.
# @param project_masters An array with the list of IPs of the Cumin master(s)
# @param project_pub_key The SSH public key used by Cumin master
# @param cluster the server cluster
# @param site the server site
# @param cumin_masters List of cumin masters
# @param permit_port_forwarding inidcate if we want port forwarding
#
class profile::openstack::eqiad1::cumin::target(
    Array $project_masters = lookup('profile::openstack::eqiad1::cumin::project_masters'),
    $project_pub_key = lookup('profile::openstack::eqiad1::cumin::project_pub_key'),
    $cluster = lookup('cluster'),
    $site = $::site,  # lint:ignore:wmf_styleguide
    Array[Stdlib::IP::Address] $cumin_masters = lookup('cumin_masters', {'default_value' => []}),
    Boolean $permit_port_forwarding = lookup('profile::openstack::eqiad1::cumin::permit_port_forwarding',
                                            {'default_value' => false}),
) {
    require network::constants

    # Include cumin::selector on all cumin targets so that
    # the wmflib::get_clusters puppet function will get results when calling
    # wmflib::puppetdb_query.
    class { 'cumin::selector':
        cluster => $cluster,
        site    => $site,
    }

    $ssh_authorized_sources = join($cumin_masters, ',')
    $project_masters_str = join($project_masters, ',')
    $pub_key = secret('keyholder/cumin_openstack_master.pub')

    ssh::userkey { 'root-cumin':
        ensure  => present,
        user    => 'root',
        skey    => 'cumin',
        content => template('profile/openstack/eqiad1/cumin/userkey.erb'),
    }

    if $project_masters_str != '' {
        ferm::conf { 'cumin-project-defs':
            content => "@def \$CUMIN_MASTERS = (${cumin_masters.join(' ')} ${project_masters_str});\n",
            prio    => '01',
        }
    }

    # Wrapper used by cumin to reboot hosts without losing the ssh connection
    file { '/usr/local/sbin/reboot-host':
        ensure => 'present',
        owner  => 'root',
        group  => 'root',
        mode   => '0550',
        source => 'puppet:///modules/cumin/reboot-host',
    }
}
