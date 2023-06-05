# sets up a mailing list server
class role::lists {

    system::role { 'lists': description => 'Mailing list server', }

    include profile::base::production
    include profile::backup::host
    include profile::firewall

    include profile::lists
    include profile::locales::extended
}
