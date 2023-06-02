# = class: role::simplelap
#
# For times when you do not want mysql, 
# and just apache and PHP
#
# This was originally created because there
# were a lot of labs instances using the old
# webserver::apache and webserver::php5 roles
# that needed to go away. This probably will
# not end up being publicly used
#
class role::simplelap{

    # TODO: another case for php_version facte
    $php_module = debian::codename() ? {
        'buster'      => 'php7.3',
        'bullseye'    => 'php7.4',
        default => fail("unsupported on ${debian::codename()}")
    }

    ensure_packages(["libapache2-mod-${php_module}", 'php-cli'])

    class { 'httpd::mpm':
        mpm => 'prefork'
    }

    class { 'httpd':
        modules             => ['rewrite', $php_module],
        purge_manual_config => false,
        require             => Class['httpd::mpm'],
    }

}
