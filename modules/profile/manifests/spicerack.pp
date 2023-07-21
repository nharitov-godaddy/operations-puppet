# SPDX-License-Identifier: Apache-2.0
# @summary Installs the spicerack library and cookbook entry point and their configuration.
#
# @param tcpircbot_host Hostname for the IRC bot.
# @param tcpircbot_port Port to use with the IRC bot.
# @param http_proxy a http_proxy to use for connections
# @param netbox_api the url for the netbox api
# @param firmware_store_dir The location to store firmware images
# @param cookbooks_repos key value pair of cookbook repos and the directory to install them to
# @param ganeti_auth_data geneti config data
# @param netbox_config_data netbox config data
# @param peeringdb_config_data peeringdb config data
# @param elasticsearch_config_data elastic config data
# @param mysql_config_data MySQL/MariaDB config data
# @param configure_redis if true configure redis
# @param configure_kafka if true configure kafka
class profile::spicerack (
    String                         $tcpircbot_host            = lookup('tcpircbot_host'),
    Stdlib::Port                   $tcpircbot_port            = lookup('tcpircbot_port'),
    String                         $http_proxy                = lookup('http_proxy'),
    Stdlib::Unixpath               $firmware_store_dir        = lookup('profile::spicerack::firmware_store_dir'),
    Hash[String, Stdlib::Unixpath] $cookbooks_repos           = lookup('profile::spicerack::cookbooks_repos'),
    Hash                           $ganeti_auth_data          = lookup('profile::spicerack::ganeti_auth_data'),
    Hash                           $netbox_config_data        = lookup('profile::spicerack::netbox_config_data'),
    Hash                           $peeringdb_config_data     = lookup('profile::spicerack::peeringdb_config_data'),
    Hash                           $elasticsearch_config_data = lookup('profile::spicerack::elasticsearch_config_data'),
    Hash                           $mysql_config_data         = lookup('profile::spicerack::mysql_config_data'),
    Hash                           $authdns_config_data       = lookup('authdns_servers'),
    Boolean                        $configure_kafka           = lookup('profile::spicerack::configure_kafka'),

) {
    ensure_packages([
        'python3-dateutil', 'python3-prettytable', 'python3-requests', 'python3-packaging',
        'spicerack', 'python3-gitlab', 'transferpy', 'python3-aiohttp', 'python3-cryptography'
    ])

    $cookbooks_repos.each |$repo, $dir| {
        wmflib::dir::mkdir_p($dir.dirname)
        git::clone { $repo:
            ensure    => 'latest',
            directory => $dir,
        }
    }

    # Kafka cluster brokers configuration
    $kafka_config_data = $configure_kafka ? {
        true    => {
          'main'   => {
              'eqiad' => kafka_config('main', 'eqiad'),
              'codfw' => kafka_config('main', 'codfw'),
          },
          'jumbo' => {
              'eqiad' => kafka_config('jumbo', 'eqiad'),
          },
          'logging' => {
              'eqiad' => kafka_config('logging', 'eqiad'),
              'codfw' => kafka_config('logging', 'codfw'),
          },
        },
        default => {},
    }

    # This is not pretty and i apologise but there is a wired bug in puppet
    # which munges undef when we pass the hash, best demonstrated with the paste below
    # https://phabricator.wikimedia.org/P42722
    # TODO: refactor this after we move to puppet >= 6
    # or possibly after https://gerrit.wikimedia.org/r/c/operations/puppet/+/868739
    $modules = {
        'elasticsearch' => { 'config.yaml'  => $elasticsearch_config_data },
        'ganeti'        => { 'config.yaml'  => $ganeti_auth_data },
        'kafka'         => { 'config.yaml'  => $kafka_config_data },
        'netbox'        => { 'config.yaml'  => $netbox_config_data },
        'peeringdb'     => { 'config.yaml'  => $peeringdb_config_data },
        'mysql'         => { 'config.yaml'  => $mysql_config_data },
        'service'       => { 'service.yaml' => wmflib::service::fetch() },
        'discovery'     => { 'authdns.yaml' => $authdns_config_data },
    }.filter |$module, $config| { !$config.values[0].empty }

    class { 'spicerack':
        tcpircbot_host => $tcpircbot_host,
        tcpircbot_port => $tcpircbot_port,
        http_proxy     => $http_proxy,
        cookbooks_dirs => $cookbooks_repos.values,
        modules        => $modules,
    }

    file { '/usr/local/bin/test-cookbook':
        ensure => file,
        source => 'puppet:///modules/profile/spicerack/test_cookbook.py',
        mode   => '0555',
    }
}
