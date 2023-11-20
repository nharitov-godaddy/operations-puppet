# SPDX-License-Identifier: Apache-2.0

# @summary a wrapper class for oauth2_proxy::oidc, plus blackbox checks

class profile::oauth2_proxy::oidc (
    # lint:ignore:wmf_styleguide
    Array[String[1]] $upstreams,
    String[1] $client_id,
    Sensitive[String[1]] $client_secret,
    Sensitive[String[1]] $cookie_secret,
    String[1] $cookie_domain,
    Stdlib::HTTPSUrl $redirect_url,
    String[1] $email_domain = 'wikimedia.org',
    Stdlib::HTTPSUrl $issuer_url = 'https://idp.wikimedia.org/oidc',
    String[1] $listen_address = '127.0.0.1:4180',
    # lint:endignore
) {
    class { 'oauth2_proxy::oidc':
        upstreams      => $upstreams,
        client_id      => $client_id,
        client_secret  => $client_secret,
        cookie_secret  => $cookie_secret,
        cookie_domain  => $cookie_domain,
        redirect_url   => $redirect_url,
        email_domain   => $email_domain,
        issuer_url     => $issuer_url,
        listen_address => $listen_address,
    }

    prometheus::blackbox::check::http { $title:
        server_name        => $cookie_domain,
        status_matches     => [ 403 ],
        body_regex_matches => [ 'Sign in with' ],
        port               => 443,
    }
}
