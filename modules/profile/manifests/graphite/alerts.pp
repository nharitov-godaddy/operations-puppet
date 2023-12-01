# SPDX-License-Identifier: Apache-2.0
# == Class: profile::graphite::alerts
#
# Install icinga alerts on graphite metrics.
# NOTE to be included only from one host, icinga will generate different alerts
# for all hosts that include this class.
#
class profile::graphite::alerts(
    Stdlib::HTTPUrl $graphite_url = lookup('graphite_url')
) {

    class {'graphite::monitoring::graphite':
        graphite_url => $graphite_url,
    }

    # Monitor MediaWiki session failures
    # See https://grafana.wikimedia.org/d/000000208/edit-count
    monitoring::graphite_threshold { 'mediawiki_session_loss':
        description     => 'MediaWiki edit session loss',
        graphite_url    => $graphite_url,
        dashboard_links => ['https://grafana.wikimedia.org/d/000000208/edit-count?orgId=1&viewPanel=13'],
        metric          => 'transformNull(scale(consolidateBy(MediaWiki.edit.failures.session_loss.rate, "max"), 60), 0)',
        warning         => 10,
        critical        => 50,
        from            => '15min',
        percentage      => 30,
        notes_link      => 'https://wikitech.wikimedia.org/wiki/Application_servers',
    }

    # Monitor MediaWiki CentralAuth bad tokens
    monitoring::graphite_threshold { 'mediawiki_bad_token':
        description     => 'MediaWiki edit failure due to bad token',
        graphite_url    => $graphite_url,
        dashboard_links => ['https://grafana.wikimedia.org/d/000000208/edit-count?orgId=1&viewPanel=13'],
        metric          => 'transformNull(scale(consolidateBy(MediaWiki.edit.failures.bad_token.rate, "max"), 60), 0)',
        warning         => 10,
        critical        => 50,
        from            => '15min',
        percentage      => 30,
        notes_link      => 'https://wikitech.wikimedia.org/wiki/Application_servers',
    }

    # Monitor MediaWiki CentralAuth login failures
    monitoring::graphite_threshold { 'mediawiki_centralauth_errors':
        description     => 'MediaWiki centralauth errors',
        graphite_url    => $graphite_url,
        dashboard_links => ['https://grafana.wikimedia.org/d/000000438/mediawiki-alerts?panelId=3&fullscreen&orgId=1'],
        metric          => 'transformNull(sumSeries(MediaWiki.authmanager.centrallogin.*.failure.*.rate), 0)',
        warning         => 0.5,
        critical        => 1,
        from            => '15min',
        percentage      => 30,
        notes_link      => 'https://wikitech.wikimedia.org/wiki/Application_servers',
    }

    # Monitor MediaWiki account creation errors are below 99%. T146090
    $account_failures = 'MediaWiki.authmanager.accountcreation.*.failure.*.sum'
    $account_success = 'MediaWiki.authmanager.accountcreation.*.success.sum'
    monitoring::graphite_threshold { 'mediawiki_accountcreation_errors':
        description     => 'MediaWiki account creation errors',
        graphite_url    => $graphite_url,
        dashboard_links => ['https://grafana.wikimedia.org/d/000000438/mediawiki-exceptions-alerts?orgId=1&forceLogin&viewPanel=23'],
        metric          => "asPercent( sumSeries(${account_failures}), sumSeries(${account_success}, ${account_failures}) )",
        warning         => 90,
        critical        => 100,
        from            => '15min',
        percentage      => 30,
        notes_link      => 'https://wikitech.wikimedia.org/wiki/Application_servers',
    }
}
