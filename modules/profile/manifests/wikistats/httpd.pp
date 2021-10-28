# sets up a webserver for wikistats
class profile::wikistats::httpd {

    # TODO: we have this php version logic in  a lot of places we shold have a phpe fact
    $php_version = debian::codename() ? {
        'stretch'  => 'php7.0',
        'buster'   => 'php7.3',
        'bullseye' => 'php7.4',
        default    => fail("unsupported on ${debian::codename()}"),
    }

    class { 'httpd':
        modules => [$php_version, 'rewrite'],
    }

    ensure_packages([
        "${php_version}-xml",
        "libapache2-mod-${php_version}",
    ])

    file { '/var/www/wikistats':
        ensure => directory,
        mode   => '0755',
        owner  => 'wikistatsuser',
        group  => 'www-data',
    }

    httpd::site { 'wikistats-cloud-vps':
        content => template('wikistats/apache/wikistats.erb'),
        require => Package["libapache2-mod-${php_version}"],
    }
}
