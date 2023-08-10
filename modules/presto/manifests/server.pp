# SPDX-License-Identifier: Apache-2.0
# Class: presto::server
#
# Sets up a Presto server, either worker or coordinator or both, depending on settings.
# The default is to set up worker only.
#
# NOTE: Do not include this class on a node that has presto::client.
#
# == Parameters
# [*enabled*]
#   If the Presto server should be running or not.
#
# [*config_properties*]
#   Properties to render into config.properties.
#
# [*node_properties*]
#   Properties to render into node.properties.
#
# [*log_properties*]
#   Properties to render into log.properties.
#
# [*catalogs*]
#   Hash of catalog names to properties.
#   Each entry in this hash will be rendered into a properties file in the
#   /etc/presto/catalogs directory.
#
# [*heap_max*]
#   Max JVM heapsize of Presto server; will be rendered into jvm.properties.
#
class presto::server(
    Boolean $enabled                    = true,
    Hash    $config_properties          = {},
    Hash    $node_properties            = {},
    Hash    $log_properties             = {},
    Hash    $catalogs                   = {},
    String  $heap_max                   = '2G',
    Optional[String] $extra_jvm_configs = undef,
) {
    if defined(Class['::presto::client']) {
        fail('Class presto::client and presto::server should not be included on the same node; presto::server will include the presto-cli package itself.')
    }

    ensure_packages('presto-cli')
    ensure_packages('presto-server')

    # Explicitly adding the 'presto' user
    # to the catalog, even if created by the presto-server package,
    # to allow other resources to require it.
    user { 'presto':
        gid        => 'presto',
        comment    => 'Presto',
        home       => '/var/lib/presto',
        shell      => '/bin/bash',
        managehome => false,
        system     => true,
        require    => Package['presto-server'],
    }

    $default_config_properties = {
        'coordinator'                        => false,
        'node-scheduler.include-coordinator' => false,
        # Use non-default http port to avoid conflicts with commonly used 8080
        'http-server.http.port'              => '8280',
        'jmx.rmiregistry.port'               => '8279',
        'discovery.uri'                      => 'http://localhost:8280',
    }

    $default_node_properties = {
        'node.environment' => 'test',
        # If node.id is not provided, then we will default to using the node's
        # fqdn with . replaced by -.
        'node.id'          => inline_template('<%= @fqdn.tr(\'.\', \'-\') %>'),
        'node.data-dir'    => '/var/lib/presto',
    }


    $default_log_properties = {
        'com.facebook.presto' => 'INFO',
    }

    presto::properties { 'config':
        properties            => $default_config_properties + $config_properties,
        may_contain_passwords => true,
    }

    $final_node_properties = $default_node_properties + $node_properties
    presto::properties { 'node':
        properties => $final_node_properties,
    }

    presto::properties { 'log':
        properties => $default_log_properties + $log_properties,
    }

    $data_dir = $final_node_properties['node.data-dir']
    file { '/etc/presto/jvm.config':
        content => template('presto/jvm.config.erb'),
    }

    # Ensure presto catalog properties files are created for each
    # defined catalog. Using ensure_resources allows us to create
    # an entry for each defined catalog without having to
    # manually declare each one.
    ensure_resources('::presto::catalog', $catalogs)


    # Make sure the $data_dir exists
    if !defined(File[$data_dir]) {
        file { $data_dir:
            ensure  => 'directory',
            owner   => 'presto',
            group   => 'presto',
            mode    => '0755',
            require => Package['presto-server'],
            before  => Service['presto-server'],
        }
    }

    # Ensure log folder is owned by presto user
    if !defined(File["${data_dir}/var"]) {
        file { "${data_dir}/var":
          ensure  => 'directory',
          owner   => 'presto',
          group   => 'presto',
          mode    => '0755',
          require => Package['presto-server'],
          before  => Service['presto-server'],
        }
    }
    if !defined(File["${data_dir}/var/log"]) {
        file { "${data_dir}/var/log":
            ensure  => 'directory',
            owner   => 'presto',
            group   => 'presto',
            mode    => '0755',
            require => Package['presto-server'],
            before  => Service['presto-server'],
        }
    }

    # By default Presto writes its logs out to $data_dir/var/log.
    # Symlink /var/log/presto to this location.
    if !defined(File['/var/log/presto']) {
        file { '/var/log/presto':
            ensure  => "${data_dir}/var/log",
            require => File[$data_dir],
        }
    }


    # Output Presto server logs to $data_dir/var/log/server.log and
    # reotate the server.log file.  http-request.log is rotated and managed
    # by Presto itself.
    logrotate::conf { 'presto-server':
        content => template('presto/logrotate.conf.erb'),
        require => Package['presto-server'],
    }
    rsyslog::conf { 'presto-server':
        content => template('presto/rsyslog.conf.erb'),
        require => Logrotate::Conf['presto-server'],
    }


    $service_ensure = $enabled ? {
        false   => 'stopped',
        default => 'running',
    }

    # Start the Presto server.
    # Presto will not auto restart on config changes.
    service { 'presto-server':
        ensure  => $service_ensure,
        require => [
            Presto::Properties['config'],
            Presto::Properties['node'],
            Presto::Properties['log'],
            File['/etc/presto/jvm.config'],
            File['/var/log/presto'],
            Rsyslog::Conf['presto-server'],
        ],
    }
}
