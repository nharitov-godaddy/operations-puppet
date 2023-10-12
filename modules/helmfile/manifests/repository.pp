# SPDX-License-Identifier: Apache-2.0
class helmfile::repository(
    String $repository,
    Stdlib::Unixpath $srcdir,
) {
    git::clone { $repository:
        ensure    => 'present',
        directory => $srcdir,
    }

    systemd::timer::job { 'git_pull_charts':
        ensure            => present,
        description       => 'Pull changes on deployment-charts repo',
        working_directory => $srcdir,
        command           => '/usr/bin/git pull',
        interval          => {
            'start'    => 'OnCalendar',
            'interval' => '*-*-* *:*:00', # every minute
        },
        logging_enabled   => false,
        user              => 'root',
    }
}
