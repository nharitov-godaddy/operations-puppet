# == Class: role::webperf::profiling_tools
#
# This role provisions a set of profiling tools for
# the performance team. (T194390)
#
class role::webperf::profiling_tools {

    system::role { 'webperf::profiling_tools':
        description => 'profiling tools host'
    }

    include ::profile::base::production
    include ::profile::firewall
    include ::profile::backup::host
    include ::profile::webperf::arclamp
    include ::profile::arclamp::redis

    # class httpd installs mpm_event by default, and once installed,
    # it cannot easily be uninstalled.
    class { '::httpd::mpm':
        mpm => 'prefork'
    }

    # Web server (for arclamp)
    class { '::httpd':
        modules => ['headers', 'mime'],
    }
}
