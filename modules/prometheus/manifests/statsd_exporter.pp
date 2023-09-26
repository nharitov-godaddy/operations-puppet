# == Define: prometheus::statsd_exporter
#
# Prometheus exporter for statsd metrics.
#
# = Parameters
#
# [*mappings*]
#   The mappings configuration for statsd exporter.
#   See also https://github.com/prometheus/statsd_exporter#metric-mapping-and-configuration
#
# [*relay_address*]
#   The host:port address where to relay received UDP traffic.
#
# [*listen_address*]
#   The host:port address where to listen for Prometheus connections.
#
# [*arguments*]
#   Additional command line arguments for prometheus-statsd-exporter.
#
# [*timer_type*]
#   summary or histogram
#
# [*histogram_buckets*]
#   Buckets for the histogram. An array of floats. Defaults to what upstream
#   defaults to
class prometheus::statsd_exporter (
    Enum['summary', 'histogram'] $timer_type,
    Array[Variant[Integer, Float]] $histogram_buckets,
    Array[Hash] $mappings = [],
    String $relay_address = '',
    String $listen_address = ':9112',
    String $arguments = '',
    Boolean $enable_scraping = true,
) {
    ensure_packages('prometheus-statsd-exporter')

    $basedir = '/etc/prometheus'
    $config = "${basedir}/statsd_exporter.conf"
    $defaults = {
      'timer_type' => $timer_type,
      'buckets'    => $histogram_buckets,
      'quantiles'  => [
        { 'quantile' => 0.99,
          'error'    => 0.001  },
        { 'quantile' => 0.95,
          'error'    => 0.001  },
        { 'quantile' => 0.75,
          'error'    => 0.001  },
        { 'quantile' => 0.50,
          'error'    => 0.005  },
      ],
    }

    if (!defined(File[$basedir])) {
        file { $basedir:
            ensure => directory,
            mode   => '0555',
            owner  => 'root',
            group  => 'root',
        }
    }

    file { $config:
        content => to_yaml({'defaults' => $defaults, 'mappings' => $mappings}),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
    }

    file { '/etc/default/prometheus-statsd-exporter':
        ensure  => present,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        content => inline_template(join(['ARGS="',
            '--statsd.mapping-config=<%= @config %>',
            '<% if not @relay_address.empty? %>--statsd.relay-address=<%= @relay_address %><% end %>',
            '--web.listen-address=<%= @listen_address %>',
            '<%= @arguments %>',
        '"'], ' ')),
        notify  => Service['prometheus-statsd-exporter'],
    }

    service { 'prometheus-statsd-exporter':
        ensure  => running,
    }

    profile::auto_restarts::service { 'prometheus-statsd-exporter': }
}
