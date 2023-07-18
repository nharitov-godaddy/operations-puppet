# SPDX-License-Identifier: Apache-2.0
class dumps::generation::server::exceptionchecker(
    $dumpsbasedir = undef,
    $user         = undef,
    $ensure       = 'present',
)  {
    file { '/usr/local/bin/dumps_exception_checker.py':
        ensure => 'present',
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/dumps/generation/dumps_exception_checker.py',
    }

    systemd::timer::job { 'dumps-exception-checker':
        ensure                  => $ensure,
        description             => 'Regular jobs to check for exceptions',
        user                    => $user,
        send_mail               => true,
        send_mail_only_on_error => false,
        monitoring_enabled      => false,
        command                 => "/usr/bin/python3 /usr/local/bin/dumps_exception_checker.py ${dumpsbasedir} 480 latest",
        environment             => {'MAILTO' => 'ops-dumps@wikimedia.org'},
        interval                => {'start' => 'OnCalendar', 'interval' => '*-*-* 0/8:40:00'},
        require                 => File['/usr/local/bin/dumps_exception_checker.py'],
    }
}
