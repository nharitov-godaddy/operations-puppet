# SPDX-License-Identifier: Apache-2.0
# Class: aptly
# Sets up a simple aptly repo server serving over http
#
# Set up to only allow root to add packages
class aptly(
    Boolean   $manage_nginx = true,
    String[1] $owner        = 'root',
    String[1] $group        = 'root',
){
    ensure_packages('aptly')
    ensure_packages('graphviz') # for aptly graph

    file { '/srv/packages':
        ensure => directory,
        owner  => $owner,
        group  => $group,
        mode   => '0755',
    }

    file { '/etc/aptly.conf':
        ensure => present,
        source => 'puppet:///modules/aptly/aptly.conf',
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
    }

    if $manage_nginx {
        nginx::site { 'aptly-server':
            source => 'puppet:///modules/aptly/aptly.nginx.conf',
        }
    }

    ferm::service { 'aptly':
        proto  => 'tcp',
        port   => '80',
        srange => '$DOMAIN_NETWORKS',
    }
}
