# runners for https://gitlab.wikimedia.org/
# https://phabricator.wikimedia.org/project/view/5555/
class role::gitlab_runner {

    system::role { 'gitlab_runner':
        description => 'virtual machine running runners for gitlab',
    }

    include profile::base::production
    include profile::firewall
    include profile::gitlab::runner
}
