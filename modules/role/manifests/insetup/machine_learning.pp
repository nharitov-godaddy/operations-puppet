# SPDX-License-Identifier: Apache-2.0
class role::insetup::machine_learning {
    include profile::base::production
    include profile::firewall
}
