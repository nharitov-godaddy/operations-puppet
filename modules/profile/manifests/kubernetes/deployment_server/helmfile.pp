# SPDX-License-Identifier: Apache-2.0
# Installs helmfile and helmfile-diff, plus
# all the puppet-provided defaults and secrets for each service.
#
class profile::kubernetes::deployment_server::helmfile (
    Profile::Kubernetes::User_defaults $user_defaults                   = lookup('profile::kubernetes::deployment_server::user_defaults'),
    Hash[String, Hash[String, Profile::Kubernetes::Services]] $services = lookup('profile::kubernetes::deployment_server::services', { 'default_value' => {} }),
    Hash[String, Any] $services_secrets                                 = lookup('profile::kubernetes::deployment_server_secrets::services', { 'default_value' => {} }),
    Hash[String, Any] $default_secrets                                  = lookup('profile::kubernetes::deployment_server_secrets::defaults', { 'default_value' => {} }),
    Hash[String, Any] $admin_services_secrets                           = lookup('profile::kubernetes::deployment_server_secrets::admin_services', { 'default_value' => {} }),
    String $helm_user_group                                             = lookup('profile::kubernetes::deployment_server::helm_user_group'),
) {
    # Add the global configuration for all deployments.
    require profile::kubernetes::deployment_server::global_config

    # Install helmfile and the repository containing helmfile deployments.
    class { 'helmfile': }
    class { 'helmfile::repository':
        repository => 'operations/deployment-charts',
        srcdir     => '/srv/deployment-charts',
    }

    $general_private_dir = "${profile::kubernetes::deployment_server::global_config::general_dir}/private"
    # Private directories for admin services
    $admin_private_dir = "${general_private_dir}/admin"
    file { $admin_private_dir:
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0750',
    }

    # Install the private values for each service
    k8s::fetch_cluster_groups().each | String $cluster_group, Hash $cluster | {
        $merged_services = deep_merge($services[$cluster_group], $services_secrets[$cluster_group])

        # Per "cluster_group" private directory for services
        $service_private_dir = "${general_private_dir}/${cluster_group}_services"
        file { $service_private_dir:
            ensure => directory,
            owner  => 'root',
            group  => $helm_user_group,
            mode   => '0750',
        }
        if $admin_services_secrets[$cluster_group] {
            $admin_services_secrets[$cluster_group].each | String $svcname, Hash $data | {
                $admin_service_dir = "${admin_private_dir}/${svcname}"
                unless defined(File[$admin_service_dir]) {
                    file { $admin_service_dir:
                        ensure  => directory,
                        owner   => 'root',
                        group   => 'root',
                        mode    => '0750',
                        force   => true,
                        recurse => true,
                    }
                }
            }
        }

        # New-style private directories are one per service, not per cluster.
        $merged_services.each | String $svcname, Hash $data | {
            $permissions = $data['private_files'] ? {
                undef   => $user_defaults,
                default => $data['private_files']
            }
            $service_dir_ensure = $data['ensure'] ? {
                undef     => directory,
                'present' => directory,
                default   => $data['ensure'],
            }
            file { "${service_private_dir}/${svcname}":
                ensure  => $service_dir_ensure,
                owner   => $permissions['owner'],
                group   => $permissions['group'],
                mode    => '0750',
                force   => true,
                recurse => true,
            }
        }

        $cluster.each() | String $cluster_name, K8s::ClusterConfig $_ | {
            $merged_services.map | String $svcname, Hash $data | {
                # Permission and file presence setup
                if $data['private_files'] {
                    $permissions = $user_defaults.merge($data['private_files'])
                } else {
                    $permissions = $user_defaults
                }
                $service_ensure = $data['ensure'] ? {
                    undef   => present,
                    default => $data['ensure'],
                }
                $raw_data = deep_merge($default_secrets[$cluster_name], $data[$cluster_name])
                # write private section only if there is any secret defined.
                unless $raw_data.empty {
                    # Substitute the value of any key in the form <somekey>: secret__<somevalue>
                    # with <somekey>: secret(<somevalue>)
                    # This allows to avoid having to copy/paste certs inside of yaml files directly,
                    # for example.
                    $secret_data = wmflib::inject_secret($raw_data)
                    file { "${service_private_dir}/${svcname}/${cluster_name}.yaml":
                        ensure  => $service_ensure,
                        owner   => $permissions['owner'],
                        group   => $permissions['group'],
                        mode    => $permissions['mode'],
                        content => to_yaml($secret_data),
                        require => "File[${service_private_dir}/${svcname}]",
                    }
                }
            }

            if $admin_services_secrets[$cluster_group] {
                $admin_services_secrets[$cluster_group].each | String $svcname, Hash $data | {
                    unless $data[$cluster_name].empty {
                        $secret_data = wmflib::inject_secret($data[$cluster_name])
                        file { "${admin_private_dir}/${svcname}/${cluster_name}.yaml":
                            owner   => 'root',
                            group   => 'root',
                            mode    => '0440',
                            content => to_yaml($secret_data),
                            require => "File[${admin_private_dir}/${svcname}]",
                        }
                    }
                }
            }
        }
    }

    # T351816: Temporary. As we have iterated over the spark-history release names,
    # which has resulted in the managment of the spark-history, spark-history-test, and
    # spark-history-analytics directories under
    # /etc/helmfile-defaults/private/dse-k8s_services/ on the deployment server,, when
    # they are no longer needed. We set them to state => absent once, and we'll remove
    # this code once it's been deployed and applied.
    ['spark-history', 'spark-history-test', 'spark-history-analytics'].each |$svc| {
        file { "${service_private_dir}/dse-k8s_services/${svc}":
            ensure => absent,
        }
    }
}
