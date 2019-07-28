class envoyproxy(
    Wmflib::Ensure $ensure,
    Stdlib::Port $admin_port,
    ) {
    package { 'envoyproxy':
        ensure => $ensure
    }
    $envoy_directory = '/etc/envoy'
    $dir_ensure = ensure_directory($ensure)

    file { $envoy_directory:
        ensure => $dir_ensure,
        owner  => 'envoy',
        group  => 'envoy',
        mode   => '0755'
    }

    # Create the subdirectories where we will store:
    # Listener and cluster definitions
    file { ["${envoy_directory}/listeners.d", "${envoy_directory}/clusters.d"]:
        ensure  => $dir_ensure,
        owner   => 'envoy',
        group   => 'envoy',
        mode    => '0755',
        recurse => true,
    }

    # Configure proper log filtering and rotation
    systemd::syslog { 'envoy':
        ensure     => $ensure,
        force_stop => true,
    }

    # build-envoy-config should generate all configuration starting from
    # the puppet-declared envoyproxy::listener and envoyproxy::cluster
    # definitions.
    #
    # It will also verify the new configuration and only put it in place if something
    # has changed.
    file { '/usr/local/sbin/build-envoy-config':
        ensure => $ensure,
        source => 'puppet:///modules/envoyproxy/files/build_envoy_config.py',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
    }

    $admin = {
        'access_log_path' => '/var/log/envoy/admin-access.log',
        'address'         => {'socket_address' => {'address' => '0.0.0.0', 'port_value' => $admin_port}}
    }

    file { "${envoy_directory}/admin-config.yaml":
        ensure  => $ensure,
        content => to_yaml($admin),
        owner   => 'root',
        group   => 'root',
        mode    => '0555',
    }

    # Used by defines to verify the configuration.
    exec { 'verify-envoy-config':
        command     => "/usr/local/sbin/build-envoy-config -c '${envoy_directory}' --verify-only",
        user        => 'root',
        refreshonly => true
    }

    systemd::service { 'envoy.service':
        ensure   => $ensure,
        content  => template('envoyproxy/systemd.conf.erb'),
        override => true,
    }
}
