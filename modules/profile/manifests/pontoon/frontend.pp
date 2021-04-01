class profile::pontoon::frontend {
    $public_services = wmflib::service::fetch().filter |$name, $config| {
        ('public_endpoint' in $config and 'role' in $config)
    }

    class { 'pontoon::public_lb':
        services_config => $public_services,
        public_domain   => $::public_domain,
    }

    class { '::httpd':
        modules => ['rewrite'],
    }

    class { 'pontoon::public_certs':
        services_config => $public_services,
        public_domain   => $::public_domain,
    }
}
