# Profile class for adding backup director functionalities to a host
#
# Note that of hiera key lookups have a name space of profile::backup instead
# of profile::backup::director. That's cause they are reused in other profile
# classes in the same hierarchy and is consistent with our code guidelines
class profile::backup::storage(
    $director = lookup('profile::backup::director'),
) {
    include profile::base::firewall
    include profile::standard


    class { 'bacula::storage':
        director           => $director,
        sd_max_concur_jobs => 5,
        sqlvariant         => 'mysql',
    }

    # TODO: Revert TLS downgrade from 1.2 to 1
    file { '/etc/ssl/openssl.cnf':
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0644',
        source => 'puppet:///modules/profile/backup/openssl.cnf',
    }

    # New setup:
    # 3 storage devices separated on 2 physical arrays
    mount { '/srv/archive' :
        ensure  => mounted,
        device  => '/dev/mapper/array1-archive',
        fstype  => 'ext4',
        require => File['/srv/archive'],
    }
    mount { '/srv/production' :
        ensure  => mounted,
        device  => '/dev/mapper/array1-production',
        fstype  => 'ext4',
        require => File['/srv/production'],
    }
    mount { '/srv/databases' :
        ensure  => mounted,
        device  => '/dev/mapper/array2-databases',
        fstype  => 'ext4',
        require => File['/srv/databases'],
    }
    file { ['/srv/archive',
            '/srv/production',
            '/srv/databases', ]:
        ensure  => directory,
        owner   => 'bacula',
        group   => 'bacula',
        mode    => '0660',
        require => Class['bacula::storage'],
    }

    bacula::storage::device { 'FileStorageArchive':
        device_type     => 'File',
        media_type      => 'File',
        archive_device  => '/srv/archive',
        max_concur_jobs => 2,
    }
    bacula::storage::device { 'FileStorageProduction':
        device_type     => 'File',
        media_type      => 'File',
        archive_device  => '/srv/production',
        max_concur_jobs => 2,
    }
    if $::site == 'eqiad' {
        bacula::storage::device { 'FileStorageDatabases':
            device_type     => 'File',
            media_type      => 'File',
            archive_device  => '/srv/databases',
            max_concur_jobs => 2,
        }
    } elsif $::site == 'codfw' {
        bacula::storage::device { 'FileStorageDatabasesCodfw':
            device_type     => 'File',
            media_type      => 'File',
            archive_device  => '/srv/databases',
            max_concur_jobs => 2,
        }
    } else {
        fail('Only eqiad or codfw pools are configured for database backups.')
    }

    nrpe::monitor_service { 'bacula_sd':
        description  => 'bacula sd process',
        nrpe_command => '/usr/lib/nagios/plugins/check_procs -w 1:1 -c 1:1 -u bacula -C bacula-sd',
        notes_url    => 'https://wikitech.wikimedia.org/wiki/Bacula',
    }

    ferm::service { 'bacula-storage-demon':
        proto  => 'tcp',
        port   => '9103',
        srange => '$PRODUCTION_NETWORKS',
    }
}
