# SPDX-License-Identifier: Apache-2.0
#
# Sets up a staging repo which will distribute packages built and
# uploaded by the CI pipeline
class role::apt_staging {
    system::role { 'apt-staging':
        description => 'Staging repo for CI generated packages, used for testing'
    }

    include profile::base::production
    include profile::firewall
    include profile::backup::host

    include profile::nginx
    include profile::aptrepo::staging
}
