# SPDX-License-Identifier: Apache-2.0
# == Class: exim4
#
# This class installs & manages Exim4 for Debian, https://exim.org/
#
# == Parameters
#
# [*config*]
#   A template for exim4.conf. Required.
#
# [*filter*]
#   A template for system_filter. Optional.
#
# [*variant*]
#   The Debian package variant. "light" or "heavy"
#
# [*queuerunner*]
#   The queue runner config option.
# @param component optional Apt component to install Exim packages from

class exim4(
  String              $config,
  Exim4::Variant      $variant     = 'light',
  Exim4::Queuerunner  $queuerunner = 'combined',
  Stdlib::Unixpath    $config_dir  = '/etc/exim4',
  Optional[String]    $filter      = undef,
  Optional[String[1]] $component   = undef,
) {
    $aliases_dir = "${config_dir}/aliases"
    $dkim_dir    = "${config_dir}/dkim"

    $packages = [
        'exim4-config',
        "exim4-daemon-${variant}",
    ]

    if $component {
        apt::package_from_component { 'exim':
            component => $component,
            packages  => $packages,
        }
    } else {
        package { $packages:
            ensure => installed,
        }
    }

    $servicestatus = $queuerunner ? {
        'queueonly' => false,
        default     => true,
    }

    service { 'exim4':
        ensure    => running,
        hasstatus => $servicestatus,
        require   => Package["exim4-daemon-${variant}"],
    }

    # mount tmpfs over the scan & db directories, for efficiency
    if $variant == 'heavy' {
        # allow o+x for /var/spool/exim4 so that subdirs below can be accessed
        file { '/var/spool/exim4':
            ensure  => directory,
            owner   => 'Debian-exim',
            group   => 'Debian-exim',
            mode    => '0751',
            require => Package["exim4-daemon-${variant}"],
        }

        # catch-22 with Puppet + mkdir/mount/chmod. The Debian package doesn't
        # ship $spool/scan, but exim4/exiscan mkdirs it on demand
        exec { 'mkdir /var/spool/exim4/scan':
            path    => '/bin:/usr/bin',
            creates => '/var/spool/exim4/scan',
            require => Package["exim4-daemon-${variant}"],
        }

        mount { [ '/var/spool/exim4/scan', '/var/spool/exim4/db' ]:
            ensure  => mounted,
            device  => 'none',
            fstype  => 'tmpfs',
            options => 'defaults',
            atboot  => true,
            require => Exec['mkdir /var/spool/exim4/scan'],
            before  => Service['exim4'],
        }

        file { [ '/var/spool/exim4/scan', '/var/spool/exim4/db' ]:
            ensure  => directory,
            owner   => 'Debian-exim',
            group   => 'Debian-exim',
            mode    => '1777',
            require => Mount['/var/spool/exim4/scan', '/var/spool/exim4/db'],
            before  => Service['exim4'],
        }
    }

    # shortcuts update-exim4.conf from messing with us
    # and stops debconf prompts about it from showing up
    file { "${config_dir}/update-exim4.conf.conf":
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => "dc_eximconfig_configtype=none\n",
        require => Package['exim4-config'],
    }

    file { '/etc/default/exim4':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => template('exim4/exim4.default.erb'),
        require => Package['exim4-config'],
    }

    file { $aliases_dir:
        ensure  => directory,
        owner   => 'root',
        group   => 'Debian-exim',
        mode    => '0755',
        require => Package['exim4-config'],
    }

    file { $dkim_dir:
        ensure  => directory,
        purge   => true,
        owner   => 'root',
        group   => 'Debian-exim',
        mode    => '0750',
        require => Package['exim4-config'],
    }

    $filter_ensure = $filter ? {
        undef   => absent,
        default => present,
    }

    file { "${config_dir}/system_filter":
        ensure  => $filter_ensure,
        owner   => 'root',
        group   => 'Debian-exim',
        mode    => '0444',
        content => $filter,
        require => Package['exim4-config'],
    }

    file { "${config_dir}/exim4.conf":
        ensure  => present,
        owner   => 'root',
        group   => 'Debian-exim',
        mode    => '0440',
        content => $config,
        require => Package['exim4-config'],
        notify  => Service['exim4'],
    }

    # Rotate the paniclog daily to prevent duplicate email notifications
    logrotate::conf { 'exim4-paniclog':
        ensure => 'present',
        source => 'puppet:///modules/exim4/logrotate/exim4-paniclog',
    }
}
