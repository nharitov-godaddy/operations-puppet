# == Class: role::thumbor::mediawiki
#
# Installs a Thumbor image scaling server to be used with MediaWiki.
#

class role::thumbor::mediawiki {

    system::role { 'thumbor::mediawiki':
        description => 'Thumbnailing server based on Thumbor',
    }

    include ::profile::base::production
    include ::profile::firewall
    include ::mediawiki::packages::fonts
    include ::profile::prometheus::haproxy_exporter
    include ::profile::prometheus::nutcracker_exporter
    include ::profile::thumbor
    include ::lvs::realserver
    include ::threedtopng::deploy
    include ::profile::prometheus::memcached_exporter

    class { '::profile::statsite':
      ensure => absent,
    }

    class { '::memcached':
        size          => 100,
        port          => 11211,
        # TODO: the following were implicit defaults from
        # MW settings, need to be reviewed.
        growth_factor => 1.05,
        min_slab_size => 5,
    }

    class {'::imagemagick::install': }

    class { '::profile::prometheus::statsd_exporter':
        relay_address => '',
    }
}
