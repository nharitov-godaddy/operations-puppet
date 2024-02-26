# This define allows you to monitor for unmerged remote changes to
# repositories that need manual merge in production as part of our workflow.
#
define monitoring::icinga::git_merge (
    $dir           = "/var/lib/git/operations/${title}",
    $user          = 'gitpuppet',
    $remote        = 'origin',
    $remote_branch = 'production',
    $interval      = 10,
    $ensure        = present
    ) {
    $sane_title = regsubst($title, '\W', '_', 'G')

    nrpe::plugin { "check_${sane_title}-needs-merge":
        content => template('monitoring/check_git-needs-merge.erb'),
    }

    nrpe::monitor_service { "${sane_title}_merged":
        ensure       => $ensure,
        description  => "Unmerged changes on repository ${title}",
        nrpe_command => "/usr/local/lib/nagios/plugins/check_${sane_title}-needs-merge",
        sudo_user    => 'root',
        retries      => $interval,
        notes_url    => 'https://wikitech.wikimedia.org/wiki/Monitoring/unmerged_changes',
    }

    sudo::user { "${sane_title}_needs_merge":
        ensure => absent,
    }
}
