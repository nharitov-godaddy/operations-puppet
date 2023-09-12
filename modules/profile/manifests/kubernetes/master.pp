# SPDX-License-Identifier: Apache-2.0
# @summary
#   This class sets up a kubernetes master (apiserver)
#
class profile::kubernetes::master (
    String $kubernetes_cluster_name = lookup('profile::kubernetes::cluster_name'),
    # TODO: Remove service_cert after T329826 is resolved
    Stdlib::Fqdn $service_cert      = lookup('profile::kubernetes::master::service_cert'),
    # TODO: Remove ssl_cert_path after T329826 is resolved
    Stdlib::Unixpath $ssl_cert_path = lookup('profile::kubernetes::master::ssl_cert_path'),
    # TODO: Remove ssl_key_path after T329826 is resolved
    Stdlib::Unixpath $ssl_key_path  = lookup('profile::kubernetes::master::ssl_key_path'),
    # TODO: Remove pki_sa_signing switch after T329826 is resolved
    Boolean        $pki_sa_signing  = lookup('profile::kubernetes::master::pki_sa_signing', { 'default_value' => false }),
    Boolean  $cergen_sa_validation  = lookup('profile::kubernetes::master::cergen_sa_validation', { 'default_value' => true }),
) {
    $k8s_config = k8s::fetch_cluster_config($kubernetes_cluster_name)
    # Comma separated list of etcd URLs is consumed by the kube-publish-sa-cert service
    # as well as k8s::apiserser so we produce it here.
    $etcd_servers = join($k8s_config['etcd_urls'], ',')

    # Install kubectl matching the masters kubernetes version
    # (that's why we don't use profile::kubernetes::client)
    class { 'k8s::client':
        version => $k8s_config['version'],
    }

    # FIXME: This should be removed after T329826 is resolved
    sslcert::certificate { $service_cert:
        ensure       => present,
        group        => 'kube',
        skip_private => false,
        use_cergen   => true,
    }
    # FIXME: With k8s 1.23 we still need this one (shared) cergen cert
    # for service-account token signing, see:
    # https://phabricator.wikimedia.org/T329826
    $cergen_sa_cert = {
        'chained' => $ssl_cert_path,
        'chain'   => '/nonexistent',
        'cert'    => $ssl_cert_path,
        'key'     => $ssl_key_path,
    }

    # The first useable IPv4 IP of the service cluster-cidr is automatically used as ClusterIP for the internal
    # kubernetes apiserver service (kubernetes.default.cluster.local)
    $apiserver_clusterip = wmflib::cidr_first_address($k8s_config['service_cluster_cidr']['v4'])
    $apiserver_cert = profile::pki::get_cert($k8s_config['pki_intermediate_base'], 'kube-apiserver', {
        'profile'         => 'server',
        'renew_seconds'   => $k8s_config['pki_renew_seconds'],
        'owner'           => 'kube',
        'outdir'          => '/etc/kubernetes/pki',
        # https://v1-23.docs.kubernetes.io/docs/setup/best-practices/certificates/#all-certificates
        'hosts'           => [
            $facts['hostname'],
            $facts['fqdn'],
            $facts['ipaddress'],
            $facts['ipaddress6'],
            $apiserver_clusterip,
            $k8s_config['master'],
            'kubernetes',
            'kubernetes.default',
            'kubernetes.default.svc',
            'kubernetes.default.svc.cluster',
            'kubernetes.default.svc.cluster.local',
        ],
        'notify_services' => ['kube-apiserver-safe-restart'],
    })

    $sa_cert = profile::pki::get_cert($k8s_config['pki_intermediate_base'], 'sa', {
        'profile'         => 'service-account-management',
        'renew_seconds'   => $k8s_config['pki_renew_seconds'],
        'owner'           => 'kube',
        'outdir'          => '/etc/kubernetes/pki',
        'notify_services' => ['kube-apiserver-safe-restart', 'kube-publish-sa-cert'],
    })

    # FIXME: T329826 by default the key of the cergen_sa_cert is used to sign service-account tokens
    # FIXME: Remove selector after T329826 is resolved
    $sa_signing_cert = $pki_sa_signing ? {
        true    => $sa_cert,
        default => $cergen_sa_cert,
    }

    $confd_prefix = '/kube-apiserver-sa-certs'
    # Add a one-shot service that writes the public sa_cert to etcd for all control-planes to fetch
    systemd::service { 'kube-publish-sa-cert':
        content => systemd_template('kubernetes-publish-sa-cert'),
    }
    # Setup a confd instance with the k8s etcd as backend (to fetch other control-planes sa certs from)
    $instances = {
        'k8s' => {
            'ensure'  => 'present',
            'backend' => 'etcdv3',
            'prefix'  => $confd_prefix,
            # confd with etcdv3 does not work well with srv_dns as it does not prepend the scheme in that case
            'hosts'   => $k8s_config['etcd_urls'],
        },
    }
    class { 'profile::confd':
        instances => $instances,
    }
    # Write out the service account certs form all control-planes into one file
    $kube_apiserver_sa_certs = '/etc/kubernetes/pki/kube-apiserver-sa-certs.pem'
    confd::file { $kube_apiserver_sa_certs:
        ensure     => present,
        instance   => 'k8s',
        watch_keys => ['/'],
        # Add all but the local cert to the file (the local one will be used unconditionally)
        content    => "{{range gets \"/*\"}}{{if ne .Key \"/${facts['fqdn']}\"}}{{.Value}}{{end}}{{end}}",
        reload     => '/bin/systemctl restart kube-apiserver-safe-restart.service',
    }

    # Add all certificates that should be used for validation of service account tokens.
    # (e.g. the local one as well as the certs from other control planes, distributed via confd)
    # FIXME: T329826 ensure we always use the cergen_sa_cert and the PKI sa_cert to validate
    #        service-account tokens to not disrupt already provisioned 1.23 clusters.
    # WARNING: T329826 when switching to $pki_sa_signing, existing sa tokens will still be signed
    #          by the cergen key. Because of that the cergen cert is still used for validation.
    $additional_sa_certs = $cergen_sa_validation ? {
        true    => [$cergen_sa_cert['cert'], $sa_cert['cert'], $kube_apiserver_sa_certs],
        default => [$sa_cert['cert'], $kube_apiserver_sa_certs],
    }

    # Client certificate used to authenticate against kubelets
    $kubelet_client_cert = profile::pki::get_cert($k8s_config['pki_intermediate_base'], 'kube-apiserver-kubelet-client', {
        'renew_seconds'   => $k8s_config['pki_renew_seconds'],
        'names'           => [{ 'organisation' => 'system:masters' }],
        'owner'           => 'kube',
        'outdir'          => '/etc/kubernetes/pki',
        'notify_services' => ['kube-apiserver-safe-restart'],
    })

    # Client cert for the front proxy (this uses a separate intermediate then everything else)
    # https://v1-23.docs.kubernetes.io/docs/tasks/extend-kubernetes/configure-aggregation-layer/
    $frontproxy_cert = profile::pki::get_cert("${k8s_config['pki_intermediate_base']}_front_proxy", 'front-proxy-client', {
        'renew_seconds'   => $k8s_config['pki_renew_seconds'],
        'owner'           => 'kube',
        'outdir'          => '/etc/kubernetes/pki',
        'notify_services' => ['kube-apiserver-safe-restart'],
    })

    # Fetch a client cert with kubernetes-admin permission
    # This is not actually used by anything but here for convenience of operators
    $default_admin_cert = profile::pki::get_cert($k8s_config['pki_intermediate_base'], 'kubernetes-admin', {
        'renew_seconds'   => $k8s_config['pki_renew_seconds'],
        'names'           => [{ 'organisation' => 'system:masters' }],
        'owner'           => 'kube',
        'outdir'          => '/etc/kubernetes/pki',
    })
    # Create a superuser kubeconfig connecting locally to this control-plane
    k8s::kubeconfig { '/etc/kubernetes/admin.conf':
        master_host => $::fqdn,
        username    => 'default-admin',
        auth_cert   => $default_admin_cert,
        owner       => 'kube',
        group       => 'kube',
    }

    class { 'k8s::apiserver':
        etcd_servers            => $etcd_servers,
        apiserver_cert          => $apiserver_cert,
        sa_cert                 => $sa_signing_cert,
        additional_sa_certs     => $additional_sa_certs,
        kubelet_client_cert     => $kubelet_client_cert,
        frontproxy_cert         => $frontproxy_cert,
        version                 => $k8s_config['version'],
        service_cluster_cidr    => $k8s_config['service_cluster_cidr'],
        service_node_port_range => $k8s_config['service_node_port_range'],
        admission_plugins       => $k8s_config['admission_plugins'],
        admission_configuration => $k8s_config['admission_configuration'],
        service_account_issuer  => $k8s_config['master_url'],
        ipv6dualstack           => $k8s_config['ipv6dualstack'],
    }

    # Setup kube-scheduler
    $scheduler_cert = profile::pki::get_cert($k8s_config['pki_intermediate_base'], 'system:kube-scheduler', {
        'renew_seconds'   => $k8s_config['pki_renew_seconds'],
        'names'           => [{ 'organisation' => 'system:kube-scheduler' }],
        'owner'           => 'kube',
        'outdir'          => '/etc/kubernetes/pki',
        'notify_services' => ['kube-scheduler'],
    })
    $scheduler_kubeconfig = '/etc/kubernetes/scheduler.conf'
    k8s::kubeconfig { $scheduler_kubeconfig:
        master_host => $k8s_config['master'],
        username    => 'default-scheduler',
        auth_cert   => $scheduler_cert,
        owner       => 'kube',
        group       => 'kube',
    }
    class { 'k8s::scheduler':
        version    => $k8s_config['version'],
        kubeconfig => $scheduler_kubeconfig,
    }

    # Setup kube-controller-manager
    $controller_manager_cert = profile::pki::get_cert($k8s_config['pki_intermediate_base'], 'system:kube-controller-manager', {
        'renew_seconds'   => $k8s_config['pki_renew_seconds'],
        'names'           => [{ 'organisation' => 'system:kube-controller-manager' }],
        'owner'           => 'kube',
        'outdir'          => '/etc/kubernetes/pki',
        'notify_services' => ['kube-controller-manager'],
    })
    $controllermanager_kubeconfig = '/etc/kubernetes/controller-manager.conf'
    k8s::kubeconfig { $controllermanager_kubeconfig:
        master_host => $k8s_config['master'],
        username    => 'default-controller-manager',
        auth_cert   => $controller_manager_cert,
        owner       => 'kube',
        group       => 'kube',
    }
    class { 'k8s::controller':
        service_account_private_key_file => $sa_signing_cert['key'],
        ca_file                          => $sa_cert['chain'],
        kubeconfig                       => $controllermanager_kubeconfig,
        version                          => $k8s_config['version'],
    }

    # All our masters are accessible to all
    ferm::service { 'apiserver-https':
        proto  => 'tcp',
        port   => '6443',
        srange => undef,
    }
}
