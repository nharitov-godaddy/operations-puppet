# SPDX-License-Identifier: Apache-2.0
class gitlab_runner::firewall (
    Stdlib::IP::Address                         $subnet,
    Wmflib::Ensure                              $ensure            = present,
    Boolean                                     $restrict_firewall = false,
    Boolean                                     $block_dockerhub   = true,
    Hash[String, Gitlab_runner::AllowedService] $allowed_services  = [],
    Stdlib::IP::Address::V4::CIDR               $internal_ip_range = '10.0.0.0/8',
) {

    ferm::conf { 'docker-ferm':
        ensure  => $ensure,
        prio    => 20,
        content => template('gitlab_runner/docker-ferm.erb'),
    }

    if $restrict_firewall {

        # reject all docker traffic to internal wmnet network
        ferm::rule { 'docker-default-reject':
            ensure => $ensure,
            prio   => 19,
            rule   => "daddr ${internal_ip_range} REJECT;",
            desc   => 'reject all docker traffic to internal wmnet network',
            chain  => 'DOCKER-ISOLATION',
        }

        # explicitly allow traffic to certain services
        $allowed_services.each | String $name, Gitlab_runner::AllowedService $allowed_service | {
            $proto = pick($allowed_service['proto'], 'tcp')
            ferm::rule { "docker-allow-${$name}":
                ensure => $ensure,
                prio   => 18,
                rule   => "daddr (@resolve(${allowed_service['host']})) proto ${proto} dport ${allowed_service['port']} ACCEPT;",
                desc   => "allow traffic to ${name} from docker",
                chain  => 'DOCKER-ISOLATION',
            }
        }
    }

    if $block_dockerhub {
        #reject all docker traffic to dockerhub
        ferm::rule { 'docker-dockerhub-reject':
            ensure => $ensure,
            prio   => 19,
            rule   => 'daddr @resolve((registry-1.docker.io docker.io index.docker.io hub.docker.com production.cloudflare.docker.com)) REJECT;',
            desc   => 'reject all docker traffic to dockerhub',
            chain  => 'DOCKER-ISOLATION',
        }
    }

}
