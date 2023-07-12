class profile::wmcs::novaproxy(
    Array[Stdlib::Fqdn]   $all_proxies                 = lookup('profile::wmcs::novaproxy::all_proxies',    {default_value => ['localhost']}),
    Stdlib::Fqdn          $active_proxy                = lookup('profile::wmcs::novaproxy::active_proxy',   {default_value => 'localhost'}),
    Optional[String]      $acme_certname               = lookup('profile::wmcs::novaproxy::acme_certname',  {default_value => undef}),
    String                $block_ua_re                 = lookup('profile::wmcs::novaproxy::block_ua_re',    {default_value => ''}),
    String                $block_ref_re                = lookup('profile::wmcs::novaproxy::block_ref_re',   {default_value => ''}),
    Array[Stdlib::Fqdn]   $xff_fqdns                   = lookup('profile::wmcs::novaproxy::xff_fqdns',      {default_value => []}),
    Array[Stdlib::IP::Address::V4] $banned_ips         = lookup('profile::wmcs::novaproxy::banned_ips',     {default_value => []}),
    Boolean               $api_readonly                = lookup('profile::wmcs::novaproxy::api_readonly',   {default_value => false}),
    Stdlib::IP::Address::V4::Nosubnet  $proxy_dns_ipv4 = lookup('profile::wmcs::novaproxy::proxy_dns_ipv4', {default_value => '198.51.100.1'}),
    Hash[String, Dynamicproxy::Zone] $supported_zones  = lookup('profile::wmcs::novaproxy::supported_zones'),
    Integer               $rate_limit_requests         = lookup('profile::wmcs::novaproxy::rate_limit_requests', {default_value => 100}),
    Enum['http', 'https'] $keystone_api_protocol       = lookup('profile::openstack::base::keystone::auth_protocol'),
    Stdlib::Port          $keystone_api_port           = lookup('profile::openstack::base::keystone::public_port'),
    # I don't want to add per-deployment profiles, so this is duplicated instead of using profile::openstack::$DEPLOYMENT::keystone_api_fqdn
    Stdlib::Fqdn          $keystone_api_fqdn           = lookup('profile::wmcs::novaproxy::keystone_api_fqdn'),
    String                $dns_updater_username        = lookup('profile::wmcs::novaproxy::dns_updater_username'),
    String                $dns_updater_project         = lookup('profile::wmcs::novaproxy::dns_updater_project'),
    String                $dns_updater_password        = lookup('profile::wmcs::novaproxy::dns_updater_password'),
    String                $token_validator_username    = lookup('profile::wmcs::novaproxy::token_validator_username'),
    String                $token_validator_project     = lookup('profile::wmcs::novaproxy::token_validator_project'),
    String                $token_validator_password    = lookup('profile::wmcs::novaproxy::token_validator_password'),
) {
    $proxy_nodes = join($all_proxies, ' ')
    # Open up redis to all proxies!
    ferm::service { 'redis-replication':
        proto  => 'tcp',
        port   => '6379',
        srange => "@resolve((${proxy_nodes}))",
    }

    ferm::service { 'http':
        proto => 'tcp',
        port  => '80',
        desc  => 'HTTP webserver for the entire world',
    }

    ferm::service { 'https':
        proto => 'tcp',
        port  => '443',
        desc  => 'HTTPS webserver for the entire world',
    }

    ferm::service { 'dynamicproxy-api-http':
        port  => '5668',
        proto => 'tcp',
        desc  => 'Web proxy management API',
    }

    if $::hostname != $active_proxy {
        $redis_replication = {
            "${::hostname}" => $active_proxy
        }
    } else {
        $redis_replication = undef
    }

    if $acme_certname != undef {
        class { '::sslcert::dhparam': }
        acme_chief::cert { $acme_certname:
            puppet_rsc => Exec['nginx-reload'],
        }

        $ssl_settings = ssl_ciphersuite('nginx', 'compat')
    } else {
        $ssl_settings = undef
    }

    class { '::dynamicproxy':
        acme_certname            => $acme_certname,
        ssl_settings             => $ssl_settings,
        xff_fqdns                => $xff_fqdns,
        luahandler               => 'domainproxy',
        redis_replication        => $redis_replication,
        banned_ips               => $banned_ips,
        blocked_user_agent_regex => $block_ua_re,
        blocked_referer_regex    => $block_ref_re,
        rate_limit_requests      => $rate_limit_requests,
    }

    class { '::dynamicproxy::api':
        acme_certname            => $acme_certname,
        ssl_settings             => $ssl_settings,
        proxy_dns_ipv4           => $proxy_dns_ipv4,
        supported_zones          => $supported_zones,
        # Read only if specified in hiera or not an active proxy
        read_only                => $api_readonly or $::hostname != $active_proxy,
        keystone_api_url         => "${keystone_api_protocol}://${keystone_api_fqdn}:${keystone_api_port}",
        dns_updater_username     => $dns_updater_username,
        dns_updater_password     => $dns_updater_password,
        dns_updater_project      => $dns_updater_project,
        token_validator_username => $token_validator_username,
        token_validator_password => $token_validator_password,
        token_validator_project  => $token_validator_project,
    }

    nginx::site { 'wmflabs.org':
        content => template('profile/wmcs/novaproxy-wmflabs.org.conf'),
    }

    # Disable the nchan module, we don't use pub/sub on nginx
    file { '/etc/nginx/modules-enabled/50-mod-nchan.conf':
        ensure => 'absent',
        notify => Service['nginx'],
    }

    class { 'prometheus::nginx_exporter': }
}

