# SPDX-License-Identifier: Apache-2.0
# @summary configuyre git repos
# @param ensure ensurable parameter
# @param basedir the git repo base dir
# @param user the owner of the git repo
# @param group the group owner of the git repo
# @param control_repo the name of the main puppet control repo
# @param repos addtional repos to configure
class profile::puppetserver::git (
    Wmflib::Ensure     $ensure       = lookup('profile::puppetserver::git::ensure'),
    Stdlib::Unixpath   $basedir      = lookup('profile::puppetserver::git::basedir'),
    String[1]          $user         = lookup('profile::puppetserver::git::user'),
    String[1]          $group        = lookup('profile::puppetserver::git::group'),
    String[1]          $control_repo = lookup('profile::puppetserver::git::control_repo'),
    Hash[String, Hash] $repos        = lookup('profile::puppetserver::git::repos'),
) {
    $servers = wmflib::role::hosts('puppetmaster::frontend') +
                wmflib::role::hosts('puppetmaster::backend') +
                wmflib::role::hosts('puppetserver')
    unless $repos.has_key($control_repo) {
        fail("\$control_repo (${control_repo}) must be defined in \$repos")
    }
    $control_repo_dir = "${basedir}/${control_repo}"
    $home_dir = "/home/${user}"

    systemd::sysuser { $user:
        home_dir => $home_dir,
        shell    => '/bin/sh',
    }

    file {"${home_dir}/.ssh":
        ensure => directory,
        owner  => $user,
        group  => $group,
        mode   => '0700',
    }
    file {
        default:
            ensure    => file,
            owner     => $user,
            group     => $group,
            mode      => '0400',
            show_diff => false;
        "${home_dir}/.ssh/id_rsa":
            content   => secret('ssh/gitpuppet/gitpuppet.key');
        "${home_dir}/.ssh/gitpuppet-private-repo":
            content   => secret('ssh/gitpuppet/gitpuppet-private.key');
    }
    ssh::userkey { $user:
        content => template('profile/puppetserver/git/gitpuppet_authorized_keys.erb'),
    }


    file { $basedir:
        ensure => stdlib::ensure($ensure, 'directory'),
        owner  => $user,
        group  => $group,
    }
    $repos.each |$repo, $config| {
        $dir = "${basedir}/${repo}"
        $origin = $config['origin'].lest || { "https://gerrit.wikimedia.org/r/${repo}" }
        ensure_resource('file', $dir.dirname, {
            ensure => stdlib::ensure($ensure, 'directory'),
            owner  => $user,
            group  => $group,
        })
        if $config['init'] {
            exec { "git init ${dir}":
                command => '/usr/bin/git init',
                user    => $user,
                group   => $group,
                cwd     => $dir,
                creates => "${dir}/.git",
                require => File[$dir.dirname],
            }
            $git_require = Exec["git init ${dir}"]
        } else {
            git::clone { $repo:
                ensure    => $ensure,
                directory => $dir,
                branch    => $config['branch'],
                origin    => $origin,
                owner     => $user,
                group     => $group,
                require   => File[$dir.dirname],
                before    => Service['puppetserver'],
            }
            $git_require = Git::Clone[$repo]
        }
        if $config.has_key('hooks') {
            $hooks_dir = "${dir}/.git/hooks"
            $config['hooks'].each |$hook, $source| {
                $content = $source.stdlib::start_with('puppet:///modules/') ? {
                    true    => {'source' => $source},
                    default => {'content' => template($source)},
                }
                file { "${hooks_dir}/${hook}":
                    ensure  => stdlib::ensure($ensure, 'file'),
                    owner   => $user,
                    group   => $group,
                    mode    => '0550',
                    require => $git_require,
                    *       => $content,
                }
            }
        }
        if $config.has_key('link') {
            file { $config['link']:
                ensure  => stdlib::ensure($ensure, 'link'),
                target  => $dir,
                force   => true,
                before  => Service['puppetserver'],
                require => $git_require,
            }
        }
        if $config.has_key('config') {
            file { "${dir}/.git/config":
                ensure  => stdlib::ensure($ensure, 'file'),
                owner   => $user,
                group   => $group,
                source  => $config['config'],
                require => $git_require,
            }
        }
    }
}
