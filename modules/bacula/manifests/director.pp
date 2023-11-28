# Class: bacula::director
#
# This class installs bacula-dir, configures it and ensures that it is running
#
# Parameters:
#   $sqlvariant
#       mysql, pgsql, sqlite3
#   $max_dir_concur_jobs
#       The maximum number of jobs this director will allow running at the same
#       time. This means it is a hard limit on the number of what the entire
#       infrastructure will do and should be tuned appropriately
#   $dir_port
#       The port the director listens on. Default 9101
#
# Actions:
#       Install bacula-dir, configure, ensure running
#
# Requires:
#
# Sample Usage:
#       class { 'bacula::director':
#           sqlvariant              => 'mysql',
#           max_dir_concur_jobs     => '10',
#       }
#
class bacula::director(
                    $sqlvariant,
                    $max_dir_concur_jobs,
                    $dir_port='9101',
                    $bconsolepassword=sha1($::uniqueid)) {

    ensure_packages(['bacula-director', "bacula-director-${sqlvariant}"])

    service { 'bacula-director':
        ensure  => running,
        # The init script bacula-director, the process bacula-dir
        pattern => 'bacula-dir',
        restart => '/usr/sbin/invoke-rc.d bacula-director reload',
        require => Package["bacula-director-${sqlvariant}"],
    }


    File <<| tag == "bacula-client-${::fqdn}" |>>
    File <<| tag == "bacula-storage-${::fqdn}" |>>

    file { '/etc/bacula/bacula-dir.conf':
        ensure  => present,
        owner   => 'bacula',
        group   => 'bacula',
        mode    => '0400',
        notify  => Service['bacula-director'],
        content => template('bacula/bacula-dir.conf.erb'),
        require => Package["bacula-director-${sqlvariant}"],
    }
    file { '/etc/bacula/director':
        ensure  => directory,
        mode    => '0550',
        owner   => 'bacula',
        group   => 'bacula',
        require => Package["bacula-director-${sqlvariant}"],
    }

    logrotate::rule { 'bacula-log':
        ensure       => present,
        file_glob    => '/var/log/bacula/log',
        frequency    => 'weekly',
        compress     => true,
        missing_ok   => true,
        not_if_empty => true,
        rotate       => 4,
    }

    # TODO: consider using profile::pki::get_cert
    puppet::expose_agent_certs { '/etc/bacula/director':
        provide_private => true,
        user            => 'bacula',
        group           => 'bacula',
        require         => File['/etc/bacula/director'],
    }

    # We will include this dir and all general options will be here
    file { '/etc/bacula/conf.d':
        ensure  => directory,
        recurse => true,
        force   => true,
        purge   => true,
        mode    => '0550',
        owner   => 'bacula',
        group   => 'bacula',
        require => Package["bacula-director-${sqlvariant}"],
    }

    # Clients will export their resources here
    file { '/etc/bacula/clients.d':
        ensure  => directory,
        recurse => true,
        force   => true,
        purge   => true,
        mode    => '0550',
        owner   => 'bacula',
        group   => 'bacula',
        require => Package["bacula-director-${sqlvariant}"],
    }

    file { '/etc/bacula/jobs.d':
        ensure  => directory,
        recurse => true,
        force   => true,
        purge   => true,
        mode    => '0550',
        owner   => 'bacula',
        group   => 'bacula',
        require => Package["bacula-director-${sqlvariant}"],
    }

    # Populating restore template/migrate jobs
    file { '/etc/bacula/jobs.d/restore-migrate-jobs.conf':
        ensure  => file,
        mode    => '0400',
        owner   => 'bacula',
        group   => 'bacula',
        require => File['/etc/bacula/jobs.d'],
        content => template('bacula/restore-migrate-jobs.conf.erb'),
    }

    # Storage daemons will export their resources here
    file { '/etc/bacula/storages.d':
        ensure  => directory,
        recurse => true,
        force   => true,
        purge   => true,
        mode    => '0550',
        owner   => 'bacula',
        group   => 'bacula',
        require => Package["bacula-director-${sqlvariant}"],
    }

    if wmflib::have_puppetdb() {
        # Exporting configuration for console users
        @@file { '/etc/bacula/bconsole.conf':
            ensure  => present,
            mode    => '0400',
            owner   => 'bacula',
            group   => 'bacula',
            content => template('bacula/bconsole.conf.erb'),
            tag     => "bacula-console-${::fqdn}",
        }
    }
}
