# == Class: mediawiki::cgroup
#
# MediaWiki uses cgroups (abbreviated from control groups) to limit the
# resource usage of commands invoked in a subprocess via Shell::command().
# The cgroup is specified by via $wgShellCgroup.
#
# See also: <https://www.mediawiki.org/wiki/Manual:$wgShellCgroup>
#
class mediawiki::cgroup {

    ensure_packages('cgroup-tools')

    # The cgroup-mediawiki-clean script is used as the release_agent
    # script for the cgroup. When the last task in the cgroup exits,
    # the kernel will run the script.

    file { '/usr/local/bin/cgroup-mediawiki-clean':
        source => 'puppet:///modules/mediawiki/cgroup/cgroup-mediawiki-clean',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    base::service_unit { 'mw-cgroup':
        ensure  => present,
        systemd => systemd_template('mw-cgroup'),
        refresh => false,
    }

    # Disable cgroup memory accounting, see: T260329
    grub::bootparam { 'cgroup.memory':
        value => 'nokmem',
    }

    # Bullseye defaults to cgroup v2 by default T325228 and our cgroup
    # setup isn't compatible with v2, so configure c1 explicitly
    if debian::codename::eq('bullseye') {
        grub::bootparam { 'disable_unified_cgroup_hierarchy':
            key   => 'systemd.unified_cgroup_hierarchy',
            value => '0',
        }
    }
}
