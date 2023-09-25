# SPDX-License-Identifier: Apache-2.0
# @summary Installs the puppet compiler and all the other software we need.
# @param ensure ensurable parameter
# @param version the version of puppet compiler to install
# @param workdir main working directory
# @param libdir main software directory
# @param user the user to run daemons
# @param group the group for dir permissions
# @param homedir the useres home dir
class puppet_compiler (
    Wmflib::Ensure   $ensure  = 'present',
    String           $version = '2.5.6',  # can and often is overridden in horizon
    Stdlib::Unixpath $workdir = '/srv/jenkins/puppet-compiler',
    Stdlib::Unixpath $libdir  = '/var/lib/catalog-differ',
    String           $user    = 'jenkins-deploy',
    String           $group   = 'jenkins-deploy',
    Stdlib::Unixpath $homedir = '/srv/home/jenkins-deploy',
) {
    $vardir = "${libdir}/puppet"
    $yamldir = "${vardir}/yaml"
    $output_dir = "${workdir}/output"
    $mount = '/mnt/nfs/labstore-secondary-project'
    $yaml_mount = "${mount}/yaml"
    $output_mount = "${mount}/output"

    ensure_packages([
        'python3-yaml', 'python3-requests', 'python3-jinja2', 'python3-clustershell',
        'nginx', 'ruby-httpclient', 'ruby-ldap', 'ruby-rgen', 'ruby-multi-json',
    ])
    file { '/usr/lib/ruby/vendor_ruby/puppet/application/master.rb':
        ensure  => stdlib::ensure($ensure, 'file'),
        content => file('puppet_compiler/puppet_master_pup-8187.rb.nocheck'),
    }

    # We cant use wmflib::dir::mkdir_p because the following creates /srv and /srv/jenkins
    # profile::ci::slave::labs::common
    file {
        default:
            ensure => stdlib::ensure($ensure, 'directory'),
            owner  => $user,
            group  => $group,
            mode   => '0644';
        [$workdir, $vardir, $libdir]: ;
        $yaml_mount:
            require => Labstore::Nfs_mount['project-on-labstore-secondary'];
        $yamldir:
            ensure => link,
            target => $yaml_mount,
            before => Class['puppet_compiler::setup'],
    }
    file { $output_dir:
        ensure  => link,
        target  => $output_mount,
        require => Labstore::Nfs_mount['project-on-labstore-secondary'],
    }

    if $ensure == 'present' {
        class { 'puppet_compiler::setup':
            user    => $user,
            vardir  => $vardir,
            homedir => $homedir,
        }
    }

    file { '/usr/local/bin/sshknowngen':
        ensure => absent,
    }
    # We don't really need some generators from puppet master, link them to
    # /bin/true
    file { '/usr/local/bin/naggen2':
        ensure => stdlib::ensure($ensure, 'link'),
        target => '/bin/true',
    }

    ## Git cloning

    # Git clone of the puppet repo
    git::clone { 'operations/puppet':
        ensure    => $ensure,
        directory => "${libdir}/production",
        owner     => $user,
        mode      => '0755',
        require   => File[$libdir],
    }

    # Git clone labs/private
    git::clone { 'labs/private':
        ensure    => $ensure,
        directory => "${libdir}/private",
        owner     => $user,
        mode      => '0755',
        require   => File[$libdir],
    }

    # Git clone labs/private
    git::clone { 'netbox-hiera':
        ensure    => $ensure,
        origin    => 'https://netbox-exports.wikimedia.org/netbox-hiera',
        directory => "${libdir}/netbox-hiera",
        owner     => $user,
        mode      => '0755',
        require   => File[$libdir],
    }

    $compiler_dir = "${libdir}/compiler"
    # Git clone the puppet compiler, install it
    git::install { 'operations/software/puppet-compiler':
        ensure    => $ensure,
        git_tag   => $version,
        directory => $compiler_dir,
        owner     => $user,
        notify    => Exec['install compiler'],
    }

    # Install the compiler
    exec { 'install compiler':
        command     => '/usr/bin/python3 setup.py install',
        user        => 'root',
        cwd         => $compiler_dir,
        refreshonly => true,
    }

    # configuration file
    file { '/etc/puppet-compiler.conf':
        ensure  => $ensure,
        owner   => $user,
        content => template('puppet_compiler/puppet-compiler.conf.erb'),
    }

    # A new, better approach is to just use confd independently. Here we
    # fake it with a file on disk
    file { '/etc/conftool-state':
        ensure => directory,
        mode   => '0755',
    }
    file { '/etc/conftool-state/mediawiki.yaml':
        ensure => stdlib::ensure($ensure, 'file'),
        mode   => '0444',
        source => 'https://config-master.wikimedia.org/mediawiki.yaml',
    }
    file { '/opt/puppetlabs/facter/cache/cached_facts/':
        owner => $user,
    }
}
