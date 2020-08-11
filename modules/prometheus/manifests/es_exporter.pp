# Prometheus Elasticsearch query metrics exporter.

class prometheus::es_exporter {
    package { 'prometheus-es-exporter':
        ensure => present,
    }

    file { '/etc/prometheus-es-exporter':
        ensure  => directory,
        recurse => true,
        purge   => true,
        force   => true,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => 'puppet:///modules/prometheus/es_exporter',
        require => Package['prometheus-es-exporter'],
        notify  => Service['prometheus-es-exporter'],
    }

    # by default, prometheus-es-exporter exports cluster, index, and node metrics generated by prometheus-elasticsearch-exporter
    # this unit override disables these metrics in prometheus-es-exporter
    systemd::service { 'prometheus-es-exporter':
        ensure   => present,
        content  => init_template('prometheus-es-exporter', 'systemd_override'),
        override => true,
        restart  => true,
    }
}
