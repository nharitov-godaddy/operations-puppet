# SPDX-License-Identifier: Apache-2.0
# == Class: bird::anycast_healthchecker
#
# Install and configure the base of anycast_healthchecker
# https://github.com/unixsurfer/anycast_healthchecker
#
# - Global configuration file
# - pid directory
# - Services checks directory
# - Log directory
# - systemd service
#
# The actual services checks are configured with bird::anycast_healthchecker_check
#
#
class bird::anycast_healthchecker(
  Optional[String]        $bind_service = undef,
  Boolean                 $do_ipv6      = false,
  Bird::Anycasthc_logging $logging      = {'level' => 'info', 'num_backups' => 8},
){

  ensure_packages(['anycast-healthchecker'])

  file { '/etc/anycast-healthchecker.conf':
      ensure       => present,
      owner        => 'bird',
      group        => 'bird',
      mode         => '0664',
      content      => template('bird/anycast-healthchecker.conf.erb'),
      validate_cmd => '/usr/bin/anycast-healthchecker --check',
      require      => Package['anycast-healthchecker'],

  }

  file {'/var/run/anycast-healthchecker/':
      ensure => directory,
      owner  => 'bird',
      group  => 'bird',
      mode   => '0775',
  }

  file {'/etc/anycast-healthchecker.d/':
      ensure  => directory,
      owner   => 'bird',
      group   => 'bird',
      mode    => '0775',
      purge   => true,
      recurse => true,
      notify  => Service['anycast-healthchecker'],
  }

  file {'/var/log/anycast-healthchecker/':
      ensure => directory,
      owner  => 'bird',
      group  => 'bird',
      mode   => '0775',
  }

  systemd::service { 'anycast-healthchecker':
      content        => template('bird/anycast-healthchecker.service.erb'),
      require        => File['/etc/anycast-healthchecker.conf',
                            '/var/run/anycast-healthchecker/',
                            '/var/log/anycast-healthchecker/',
                            '/etc/anycast-healthchecker.d/',],
      restart        => true,
      service_params => {
          ensure     => 'running', # lint:ignore:ensure_first_param
      },
  }
}
