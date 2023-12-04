# == Class archiva::proxy
# Sets up a simple nginx reverse proxy.
# This must be included on the same node as the archiva server.
#
# This depends on the nginx, ferm, and sslcert modules from WMF operations/puppet/modules.
#
# == Parameters
# $ssl_enabled        - If true, this proxy will do SSL and force redirect to HTTPS.  Default: true
#
# $certificate_name   - Name of certificate.  If this is anything but 'ssl-cert-snakeoil',
#                       the certificate will be retrieved via acme-chief.
#                       If this is 'ssl-cert-snakeoil', the snakeoil certificate will be used.
#                       It is expected to be found at /etc/ssl/certs/ssl-cert-snakeoil.pem.
#                       Default: archiva
#
class archiva::proxy(
    $ssl_enabled      = true,
    $certificate_name = 'archiva',
) {
    Class['::archiva'] -> Class['::archiva::proxy']

    # $archiva_server_properties and
    # $ssl_server_properties will be concatenated together to form
    # a single $server_properties array for proxy.nginx.erb
    # nginx site template.
    $archiva_server_properties = [
        # Need large body size to allow for .jar deployment.
        'client_max_body_size 256M;',
        # Archiva sometimes takes a long time to respond.
        'proxy_connect_timeout 600s;',
        'proxy_read_timeout 600s;',
        'proxy_send_timeout 600s;',
    ]

    if $ssl_enabled {
        $listen = '443 ssl'

        # Install the certificate if it is not the snakeoil cert
        if $certificate_name != 'ssl-cert-snakeoil' {
            acme_chief::cert { $certificate_name:
                puppet_svc => 'nginx',
            }

            $ssl_ecdsa_certificate_chained = "/etc/acmecerts/${certificate_name}/live/ec-prime256v1.chained.crt"
            $ssl_ecdsa_certificate_key = "/etc/acmecerts/${certificate_name}/live/ec-prime256v1.key"
            $ssl_rsa_certificate_chained = "/etc/acmecerts/${certificate_name}/live/rsa-2048.chained.crt"
            $ssl_rsa_certificate_key = "/etc/acmecerts/${certificate_name}/live/rsa-2048.key"

            $tls_server_properties = [
                "ssl_certificate     ${ssl_ecdsa_certificate_chained};",
                "ssl_certificate_key ${ssl_ecdsa_certificate_key};",
                "ssl_certificate     ${ssl_rsa_certificate_chained};",
                "ssl_certificate_key ${ssl_rsa_certificate_key};",
            ]
        } else {
            $ssl_certificate_chained = '/etc/ssl/certs/ssl-cert-snakeoil.pem'
            $tls_server_properties = [
                "ssl_certificate     ${ssl_certificate_chained};",
            ]
        }

        # Use puppet's stupidity to flatten these into a single array.
        $server_properties = [
            $archiva_server_properties,
            ssl_ciphersuite('nginx', 'mid', true),
            $tls_server_properties,
        ]

    }
    else {
        $listen = 80
        $server_properties = $archiva_server_properties
    }

    $proxy_pass = "http://127.0.0.1:${::archiva::port}/"

    nginx::site { 'archiva':
        content => template('archiva/proxy.nginx.erb'),
    }

    profile::auto_restarts::service { 'nginx': }
}
