# SPDX-License-Identifier: Apache-2.0
class role::insetup::data_engineering {
    system::role { 'insetup::data_engineering':
        ensure      => 'present',
        description => 'Host being setup by Data Engineering SREs',
    }

    include profile::base::production
    include profile::firewall
}
