# Sets up a webserver (nginx) and an APT repository.
class role::apt_repo {
    system::role { 'webserver-and-APT-repository': }

    include profile::base::production
    include profile::firewall
    include profile::backup::host
    include profile::base::cuminunpriv

    include profile::nginx
    include profile::installserver::http
    include profile::installserver::preseed
    include profile::aptrepo::wikimedia
}
