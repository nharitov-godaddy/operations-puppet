# SPDX-License-Identifier: Apache-2.0
# @summary
#   This class sets up a kubernetes master (apiserver)
#
class profile::kubernetes::master (
    K8s::KubernetesVersion $version = lookup('profile::kubernetes::version', { default_value => '1.16' }),
    String $kubernetes_cluster_group = lookup('profile::kubernetes::master::cluster_group'),
    Stdlib::Fqdn $master_fqdn = lookup('profile::kubernetes::master_fqdn'),
    Array[String] $etcd_urls=lookup('profile::kubernetes::master::etcd_urls'),
    # List of hosts the kubernetes apiserver (tcp/6443) is accessible to.
    # SPECIAL VALUE: use 'all' to have the apiserver be open to the world
    String $accessible_to=lookup('profile::kubernetes::master::accessible_to'),
    K8s::ClusterCIDR $service_cluster_cidr=lookup('profile::kubernetes::service_cluster_cidr'),
    Optional[String] $service_node_port_range=lookup('profile::kubernetes::master::service_node_port_range', { 'default_value' => undef }),
    # TODO: Remove service_cert after all clusters are 1.23
    Stdlib::Fqdn $service_cert=lookup('profile::kubernetes::master::service_cert'),
    # TODO: Remove ssl_cert_path after all clusters are 1.23
    Stdlib::Unixpath $ssl_cert_path=lookup('profile::kubernetes::master::ssl_cert_path'),
    # TODO: Remove ssl_key_path after all clusters are 1.23
    Stdlib::Unixpath $ssl_key_path=lookup('profile::kubernetes::master::ssl_key_path'),
    Stdlib::Httpurl $prometheus_url=lookup('profile::kubernetes::master::prometheus_url', { 'default_value' => "http://prometheus.svc.${::site}.wmnet/k8s" }),
    Optional[String] $runtime_config=lookup('profile::kubernetes::master::runtime_config', { 'default_value' => undef }),
    Boolean $allow_privileged = lookup('profile::kubernetes::master::allow_privileged', { default_value => false }),
    String $controllermanager_token = lookup('profile::kubernetes::master::controllermanager_token'),
    String $scheduler_token = lookup('profile::kubernetes::master::scheduler_token'),
    Hash[String, Profile::Kubernetes::User_tokens] $all_infrastructure_users = lookup('profile::kubernetes::infrastructure_users'),
    Optional[K8s::AdmissionPlugins] $admission_plugins = lookup('profile::kubernetes::master::admission_plugins', { default_value => undef }),
    Optional[Array[Hash]] $admission_configuration = lookup('profile::kubernetes::master::admission_configuration', { default_value => undef }),
    Boolean $ipv6dualstack = lookup('profile::kubernetes::ipv6dualstack', { default_value => false }),
    # It is expected that there is a second intermediate suffixed with _front_proxy to be used
    # to configure the aggregation layer. So by setting "wikikube" here you are required to add
    # the intermediates "wikikube" and "wikikube_front_proxy".
    #
    # FIXME: This should be something like "cluster group/name" while retaining the discrimination
    #        between production and staging as we don't want to share the same intermediate across
    #        that boundary.
    # FIXME: This is *not* optional for k8s versions > 1.16
    Optional[Cfssl::Ca_name] $pki_intermediate = lookup('profile::kubernetes::pki::intermediate', { default_value => undef }),
    # 952200 seconds is the default from cfssl::cert:
    # the default https checks go warning after 10 full days i.e. anywhere
    # from 864000 to 950399 seconds before the certificate expires.  As such set this to
    # 11 days + 30 minutes to capture the puppet run schedule.
    Integer[1800] $pki_renew_seconds = lookup('profile::kubernetes::pki::renew_seconds', { default_value => 952200 })
) {
    $k8s_le_116 = versioncmp($version, '1.16') <= 0

    if $k8s_le_116 {
        # On k8s 1.16 cluster, use cergen
        sslcert::certificate { $service_cert:
            ensure       => present,
            group        => 'kube',
            skip_private => false,
            use_cergen   => true,
        }
        $apiserver_cert = {
            'chained' => $ssl_cert_path,
            'chain'   => '/nonexistent',
            'cert'    => $ssl_cert_path,
            'key'     => $ssl_key_path,
        }
        # We use the same certificate for service-account token signing in 1.16
        $sa_cert = $apiserver_cert

        # All other certs are unused with k8s 1.16
        $nonexistent_cert = {
            'chained' => '/nonexistent',
            'chain'   => '/nonexistent',
            'cert'    => '/nonexistent',
            'key'     => '/nonexistent',
        }
        $kubelet_client_cert = $nonexistent_cert
        $frontproxy_cert = $nonexistent_cert
    } else {
        if $pki_intermediate == undef {
            fail('profile::kubernetes::pki::intermediate is mandatory for k8s = 1.16')
        }
        $apiserver_cert = profile::pki::get_cert($pki_intermediate, 'kube-apiserver', {
            'profile'        => 'server',
            'renew_seconds'  => $pki_renew_seconds,
            'owner'          => 'kube',
            'outdir'         => '/etc/kubernetes/pki',
            # https://v1-23.docs.kubernetes.io/docs/setup/best-practices/certificates/#all-certificates
            'hosts'          => [
                $facts['hostname'],
                $facts['fqdn'],
                $facts['ipaddress'],
                $facts['ipaddress6'],
                $master_fqdn,
                'kubernetes',
                'kubernetes.default',
                'kubernetes.default.svc',
                'kubernetes.default.svc.cluster',
                'kubernetes.default.svc.cluster.local',
            ],
            'notify_service' => 'kube-apiserver'
        })
        $sa_cert = profile::pki::get_cert($pki_intermediate, 'sa', {
            'profile'        => 'service-account-management',
            'renew_seconds'  => $pki_renew_seconds,
            'owner'          => 'kube',
            'outdir'         => '/etc/kubernetes/pki',
            'notify_service' => 'kube-apiserver'
        })

        # Client certificate used to authenticate against kubelets
        $kubelet_client_cert = profile::pki::get_cert($pki_intermediate, 'kube-apiserver-kubelet-client', {
            'renew_seconds'  => $pki_renew_seconds,
            'names'          => [{ 'organisation' => 'system:masters' }],
            'owner'          => 'kube',
            'outdir'         => '/etc/kubernetes/pki',
            'notify_service' => 'kube-apiserver'
        })

        # Client cert for the front proxy (this uses a separate intermediate then everything else)
        # https://v1-23.docs.kubernetes.io/docs/tasks/extend-kubernetes/configure-aggregation-layer/
        $frontproxy_cert = profile::pki::get_cert("${pki_intermediate}_front_proxy", 'front-proxy-client', {
            'renew_seconds'  => $pki_renew_seconds,
            'owner'          => 'kube',
            'outdir'         => '/etc/kubernetes/pki',
            'notify_service' => 'kube-apiserver'
        })

        # FIXME: superuser kubeconfig is not actually needed on masters
        # Fetch a client cert with kubernetes-admin permission
        $default_admin = profile::pki::get_cert($pki_intermediate, 'kubernetes-admin', {
            'renew_seconds'  => $pki_renew_seconds,
            'names'           => [{ 'organisation' => 'system:masters' }],
            'owner'           => 'kube',
            'outdir'          => '/etc/kubernetes/pki',
        })
        # Create a supersuer kubeconfig
        k8s::kubeconfig { '/etc/kubernetes/admin.conf':
            master_host => $master_fqdn,
            username    => 'default-admin',
            auth_cert   => $default_admin,
            owner       => 'kube',
            group       => 'kube',
        }
    }

    $etcd_servers = join($etcd_urls, ',')
    # Get the local users and the corresponding tokens.
    $_users = $all_infrastructure_users[$kubernetes_cluster_group].filter |$_,$data| {
        # If "constrain_to" is defined, restrict the user to the masters that meet the regexp
        $data['constrain_to'] ? {
            undef => true,
            default => ($facts['fqdn'] =~ Regexp($data['constrain_to']))
        }
    }
    # Ensure all tokens are unique.
    # Kubernetes will use the last definition of a token, so strange things might
    # happen if a token is used twice.
    $_tokens = $_users.map |$_,$data| { $data['token'] }
    if $_tokens != $_tokens.unique {
        fail('Not all tokens in profile::kubernetes::infrastructure_users are unique')
    }

    class { 'k8s::apiserver':
        etcd_servers            => $etcd_servers,
        apiserver_cert          => $apiserver_cert,
        sa_cert                 => $sa_cert,
        kubelet_client_cert     => $kubelet_client_cert,
        frontproxy_cert         => $frontproxy_cert,
        users                   => $_users,
        allow_privileged        => $allow_privileged,
        version                 => $version,
        service_cluster_cidr    => $service_cluster_cidr,
        service_node_port_range => $service_node_port_range,
        runtime_config          => $runtime_config,
        admission_plugins       => $admission_plugins,
        admission_configuration => $admission_configuration,
        service_account_issuer  => "https://${master_fqdn}:6443",
        ipv6dualstack           => $ipv6dualstack,
    }

    # Setup kube-scheduler
    if $k8s_le_116 {
        $scheduler_kubeconfig = '/etc/kubernetes/scheduler_config'
        k8s::kubeconfig { $scheduler_kubeconfig:
            master_host => $master_fqdn,
            username    => 'system:kube-scheduler',
            token       => $scheduler_token,
            owner       => 'kube',
            group       => 'kube',
        }
    } else {
        $default_scheduler = profile::pki::get_cert($pki_intermediate, 'system:kube-scheduler', {
            'renew_seconds'  => $pki_renew_seconds,
            'names'          => [{ 'organisation' => 'system:kube-scheduler' }],
            'owner'          => 'kube',
            'outdir'         => '/etc/kubernetes/pki',
            'notify_service' => 'kube-scheduler',
        })
        $scheduler_kubeconfig = '/etc/kubernetes/scheduler.conf'
        k8s::kubeconfig { $scheduler_kubeconfig:
            master_host => $master_fqdn,
            username    => 'default-scheduler',
            auth_cert   => $default_scheduler,
            owner       => 'kube',
            group       => 'kube',
        }
    }
    class { 'k8s::scheduler':
        version    => $version,
        kubeconfig => $scheduler_kubeconfig,
    }

    # Setup kube-controller-manager
    if $k8s_le_116 {
        $controllermanager_kubeconfig = '/etc/kubernetes/controller-manager_config'
        k8s::kubeconfig { $controllermanager_kubeconfig:
            master_host => $master_fqdn,
            username    => 'system:kube-controller-manager',
            token       => $controllermanager_token,
            owner       => 'kube',
            group       => 'kube',
        }
    } else {
        $default_controller_manager = profile::pki::get_cert($pki_intermediate, 'system:kube-controller-manager', {
            'renew_seconds'  => $pki_renew_seconds,
            'names'          => [{ 'organisation' => 'system:kube-controller-manager' }],
            'owner'          => 'kube',
            'outdir'         => '/etc/kubernetes/pki',
            'notify_service' => 'kube-controller-manager',
        })
        $controllermanager_kubeconfig = '/etc/kubernetes/controller-manager.conf'
        k8s::kubeconfig { $controllermanager_kubeconfig:
            master_host => $master_fqdn,
            username    => 'default-controller-manager',
            auth_cert   => $default_controller_manager,
            owner       => 'kube',
            group       => 'kube',
        }
    }
    class { 'k8s::controller':
        service_account_private_key_file => $sa_cert['key'],
        ca_file                          => $sa_cert['chain'],
        kubeconfig                       => $controllermanager_kubeconfig,
        version                          => $version,
    }

    # Setup ferm rules
    if $accessible_to == 'all' {
        $accessible_range = undef
    } else {
        $accessible_to_ferm = join($accessible_to, ' ')
        $accessible_range = "(@resolve((${accessible_to_ferm})) @resolve((${accessible_to_ferm}), AAAA))"
    }

    ferm::service { 'apiserver-https':
        proto  => 'tcp',
        port   => '6443',
        srange => $accessible_range,
    }
}
