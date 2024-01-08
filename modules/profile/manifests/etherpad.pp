# SPDX-License-Identifier: Apache-2.0
# sets up an Etherpad lite server
class profile::etherpad(
    Stdlib::IP::Address $listen_ip = lookup('profile::etherpad::listen_ip'),
){

    include ::passwords::etherpad_lite
    include ::profile::prometheus::etherpad_exporter

    class { '::etherpad':
        etherpad_db_user => $passwords::etherpad_lite::etherpad_db_user,
        etherpad_db_host => $passwords::etherpad_lite::etherpad_db_host,
        etherpad_db_name => $passwords::etherpad_lite::etherpad_db_name,
        etherpad_db_pass => $passwords::etherpad_lite::etherpad_db_pass,
        etherpad_ip      => $listen_ip,
    }

    prometheus::blackbox::check::http { 'etherpad-envoy':
        server_name        => 'etherpad.wikimedia.org',
        team               => 'collaboration-services',
        severity           => 'task',
        path               => '/',
        ip_families        => ['ip4'],
        port               => 7443,
        force_tls          => true,
        body_regex_matches => ['Pad'],
    }

    prometheus::blackbox::check::http { 'etherpad-nodejs':
        server_name        => 'etherpad.wikimedia.org',
        team               => 'collaboration-services',
        severity           => 'task',
        path               => '/',
        ip_families        => ['ip6'],
        port               => 9001,
        force_tls          => false,
        body_regex_matches => ['Pad'],
    }

    firewall::service { 'etherpad_service':
        proto    => 'tcp',
        port     => 9001,
        src_sets => ['CACHES'],
    }

    profile::auto_restarts::service { 'envoyproxy': }

    # Ship etherpad server logs to ELK using startmsg_regex pattern to join multi-line events based on datestamp
    # example: [2018-11-30 21:32:43.412]
    rsyslog::input::file { 'etherpad-multiline':
        path           => '/var/log/etherpad-lite/etherpad-lite.log',
        startmsg_regex => '^\\\\[[0-9,-\\\\ \\\\:]+\\\\]',
    }
}
