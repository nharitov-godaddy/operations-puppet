# Sets up a web server to be used by mailman.
class mailman::webui (
    Stdlib::Fqdn $lists_servername,
    Hash[String, String] $renamed_lists,
    Optional[String] $acme_chief_cert = undef,
){

    $ssl_settings = ssl_ciphersuite('apache', 'mid', true)

    httpd::site { $lists_servername:
        content => template('mailman/apache.conf.erb'),
    }

    # Add files in /var/www (docroot)
    file { '/var/www':
        source  => 'puppet:///modules/mailman/docroot/',
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        recurse => 'remote',
    }

    # Not using require_package so apt::pin may be applied
    # before attempting to install package.
    package { 'libapache2-mod-security2':
        ensure => present,
    }

    # Ensure that the CRS modsecurity ruleset is not used. it has not
    # yet been tested for compatibility with our mailman instance and may
    # cause breakage.
    file { '/etc/apache2/mods-available/security2.conf':
        ensure  => present,
        source  => 'puppet:///modules/mailman/modsecurity/security2.conf',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => Package['libapache2-mod-security2'],
    }

}
