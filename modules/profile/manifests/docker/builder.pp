# SPDX-License-Identifier: Apache-2.0
# == Class profile::docker::builder
#
# This class sets up a docker builder server, where our base images can be built
# and uploaded to the docker registry.
#
# === Parameters
#
# [*proxy_address*] The http proxy address, set to undef if you don't want to use item
#
# [*proxy_port*] The http proxy port; set to undef if not needed
#
# [*registry*] Address of the docker registry.
#
# [*password*] password for the "prod-build" user on the docker registry.
#
# [*imageupdate_git_key*] ssh private key for the image update process
#
# [*docker_pkg*] Boolean value for enabling the docker_pkg component
#
class profile::docker::builder(
    Optional[Stdlib::Host] $proxy_address = lookup('profile::docker::builder::proxy_address', {default_value => undef}),
    Optional[Stdlib::Port] $proxy_port = lookup('profile::docker::builder::proxy_port', {default_value => undef}),
    Stdlib::Host $registry = lookup('docker::registry'),
    String $password = lookup('profile::docker::builder::prod_build_password'),
    String $imageupdate_git_key = lookup('profile::docker::builder::imageupdate_git_key'),
    Boolean $docker_pkg = lookup('profile::docker::docker_pkg', {default_value => false}),
    Boolean $prune_prod_images = lookup('profile::docker::builder::prune_images'),
    Boolean $rebuild_images = lookup('profile::docker::builder::rebuild_images'),
    Hash[String,Integer] $known_uid_mappings = lookup('profile::docker::builder::known_uid_mappings', {default_value => undef})
){

    if $docker_pkg {
        class { '::docker_pkg': }
    }

    class { 'service::deploy::common': }

    class { 'docker::baseimages':
        docker_registry => $registry,
        proxy_address   => $proxy_address,
        proxy_port      => $proxy_port,
        distributions   => ['bookworm', 'bullseye', 'buster'],
        skip_distro     => [],
    }

    ensure_packages(['python3-virtualenv', 'virtualenv'])

    git::clone { 'operations/docker-images/production-images':
        ensure    => present,
        directory => '/srv/images/production-images'
    }

    file {'/etc/production-images':
        ensure => directory,
        mode   => '0700',
    }

    file { '/etc/production-images/config.yaml':
        ensure  => present,
        content => template('profile/docker/production-images-config.yaml.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444'
    }

    file { '/etc/production-images/config-istio.yaml':
        ensure  => present,
        content => template('profile/docker/production-images-config-istio.yaml.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444'
    }

    file { '/etc/production-images/config-cert-manager.yaml':
        ensure  => present,
        content => template('profile/docker/production-images-config-cert-manager.yaml.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444'
    }

    file { '/usr/local/bin/build-production-images':
        ensure => present,
        source => 'puppet:///modules/profile/docker/build-production-images.sh',
        owner  => 'root',
        group  => 'root',
        mode   => '0500'
    }

    file { '/usr/local/bin/manage-production-images':
        ensure => present,
        source => 'puppet:///modules/profile/docker/manage-production-images.sh',
        owner  => 'root',
        group  => 'root',
        mode   => '0500'
    }

    # Cleanup old images at the start of the month.
    if $prune_prod_images {
        systemd::timer::job { 'prune-production-images':
            description     => 'Periodic job to prune old docker images',
            command         => '/usr/local/bin/manage-production-images prune',
            interval        => {'start' => 'OnCalendar', 'interval' => '*-*-01 04:00:00'},
            user            => 'root',
            logfile_basedir => '/var/log'
        }
    }

    docker::credentials { '/root/.docker/config.json':
        owner             => 'root',
        group             => 'root',
        registry          => $registry,
        registry_username => 'prod-build',
        registry_password => $password,
    }

    $timer_ensure = $rebuild_images ? {
        true    => 'present',
        default => 'absent',
    }
    # Cronjob to refresh the production-images every week on sunday.
    # Special clone of production-images
    $imageupdatebot_base = '/usr/src/imageupdatebot'
    file { $imageupdatebot_base:
        ensure => $rebuild_images.bool2str('directory', 'absent'),
        owner  => 'root',
        group  => 'root',
    }
    $ssh_key_location = "${imageupdatebot_base}/.ssh.key"
    file { $ssh_key_location:
        ensure  => $rebuild_images.bool2str('present', 'absent'),
        content => $imageupdate_git_key,
        owner   => 'root',
        group   => 'root',
        mode    => '0400',
    }
    git::clone { 'imageupdatebot/production-images':
        ensure    => $rebuild_images.bool2str('present', 'absent'),
        origin    => 'ssh://imageupdatebot@gerrit.wikimedia.org:29418/operations/docker-images/production-images',
        ssh       => "ssh -i ${ssh_key_location}",
        directory => "${imageupdatebot_base}/production-images"
    }
    # The actual script to run
    file { '/usr/local/bin/update-production-images':
        ensure => $rebuild_images.bool2str('present', 'absent'),
        owner  => 'root',
        group  => 'root',
        mode   => '0544',
        source => 'puppet:///modules/profile/docker/update-production-images.sh'
    }
    systemd::timer::job { 'production-images-weekly-rebuild':
        ensure              => $timer_ensure,
        description         => 'Weekly job to rebuild the production-images',
        command             => '/usr/local/bin/build-production-images --nightly',
        interval            => {'start' => 'OnCalendar', 'interval' => 'Sun *-*-* 06:00:00'},
        user                => 'root',
        after               => 'debian-weekly-rebuild.service',
        max_runtime_seconds => 86400,
    }
}
