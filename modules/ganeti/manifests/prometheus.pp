# SPDX-License-Identifier: Apache-2.0
# Class ganeti::prometheus
#
# Install Prometheus exporter for Ganeti
#

class ganeti::prometheus(
    String $rapi_endpoint,
    String $rapi_ro_user,
    String $rapi_ro_password,
) {
    ensure_packages('prometheus-ganeti-exporter')

    firewall::service {'ganeti-prometheus-exporter':
        proto    => 'tcp',
        port     => 8080,
        src_sets => ['PRODUCTION_NETWORKS'],
    }

    # Configuration files for Ganeti Prometheus exporter
    file { '/etc/ganeti/prometheus.ini':
        ensure  => present,
        owner   => 'prometheus',
        group   => 'prometheus',
        mode    => '0400',
        content => template('ganeti/prometheus-collector.erb')
    }

    service {'prometheus-ganeti-exporter':
        ensure => running,
    }

    profile::auto_restarts::service { 'prometheus-ganeti-exporter': }
}
