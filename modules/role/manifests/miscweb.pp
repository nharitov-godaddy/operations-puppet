# a webserver for misc. apps and static sites
class role::miscweb {

    system::role { 'miscweb':
        description => 'WMF misc apps and sites web server'
    }

    include profile::base::production            # base tools
    include profile::firewall                    # firewalling
    include profile::backup::host                # Bacula backups 
    include profile::miscweb::httpd              # common webserver setup
    include profile::miscweb::rsync              # copy data for migrations
    include profile::tlsproxy::envoy             # TLS termination

    include profile::microsites::static_rt       # https://static-rt.wikimedia.org
    include profile::microsites::transparency    # https://transparency.wikimedia.org
    include profile::microsites::research        # https://research.wikimedia.org (T183916)
    include profile::microsites::design          # https://design.wikimedia.org (T185282)
    include profile::microsites::sitemaps        # https://sitemaps.wikimedia.org
    include profile::microsites::wikiworkshop    # https://wikiworkshop.org (T242374)
    include profile::microsites::static_codereview # https://static-codereview.wikimedia.org (T243056)
    include profile::microsites::security        # https://security.wikimedia.org (T257830)
    include profile::microsites::query_service   # parts of https://query.wikidata.org (T266702)
    include profile::microsites::os_reports      # https://os-reports.wikimedia.org
    include profile::microsites::static_tendril  # https://tendril.wikimedia.org and dbtree.wikimedia.org (T297605)
    include profile::microsites::monitoring      # Contains blackbox checks for miscweb services on Kubernetes (T300171)
}
