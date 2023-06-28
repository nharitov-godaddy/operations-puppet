# SPDX-License-Identifier: Apache-2.0
class gdnsd {
    # The package would create this as well if missing, but this allows
    # puppetization to create directories and files owned by these before the
    # package is even installed...

    systemd::sysuser { 'gdnsd':
        home_dir    => '/var/run/gdnsd',
    }

    package { 'gdnsd':
        ensure => installed,
    }

    # Ensure that 'restarts' are converted to seamless reloads; it never needs
    # a true restart under any remotely normal conditions.
    systemd::service { 'gdnsd':
        require        => Package['gdnsd'],
        content        => file('gdnsd/initscripts/gdnsd-override.service'),
        override       => true,
        service_params => {
            restart   => '/bin/systemctl reload gdnsd',
        },
    }
}
