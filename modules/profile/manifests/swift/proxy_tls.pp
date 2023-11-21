# SPDX-License-Identifier: Apache-2.0
class profile::swift::proxy_tls (
    String $ocsp_proxy = lookup('http_proxy', {'default_value' => ''}),
    Boolean $use_envoy = lookup('profile::swift::proxy::use_envoy', {'default_value' => false}),
){

    if $use_envoy {
        include profile::tlsproxy::envoy
    } else {
        require ::profile::tlsproxy::instance

        tlsproxy::localssl { 'unified':
            server_name    => $::swift::proxy::proxy_service_host,
            certs          => [$::swift::proxy::proxy_service_host],
            default_server => true,
            do_ocsp        => false,
            ocsp_proxy     => $ocsp_proxy,
            enable_http2   => false,
        }
    }

    ferm::service { 'swift-proxy-https':
        proto   => 'tcp',
        notrack => true,
        port    => '443',
    }
}
