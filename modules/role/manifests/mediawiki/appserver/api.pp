class role::mediawiki::appserver::api {
    system::role { 'mediawiki::appserver::api': }
    include ::profile::base::production
    include ::role::mediawiki::common

    include ::profile::firewall
    include ::profile::prometheus::apache_exporter
    include ::profile::mediawiki::php::monitoring
    include ::profile::mediawiki::webserver
    include ::profile::mediawiki::api
    # restart php-fpm if the opcache available is too low
    include ::profile::mediawiki::php::restarts
}
