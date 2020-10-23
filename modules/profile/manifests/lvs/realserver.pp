# == Class profile::lvs::realserver.
# Sets up the lvs realserver IPs and the corresponding conftool-based scripts
#
# === Parameters
#
# [*pools*] Pools in the format: {$lvs_name => { services => [$svc1,$svc2,...] }
#           where the services listed are the ones that are needed to serve the lvs pool.
#           So for example if you need both apache and php7 to serve a request from a pool,
#           both should be included.
#
# [*use_conftool*] Whether to use conftool or not.
#
# [*poolcounter_backends*] List of poolcounter servers, and their shard labels. See type
#                          Poolcounter::Backends for the format.
#
class profile::lvs::realserver(
    Hash $pools = hiera('profile::lvs::realserver::pools', {}),
    Boolean $use_conftool = hiera('profile::lvs::realserver::use_conftool'),
    Optional[Poolcounter::Backends] $poolcounter_backends = lookup('profile::lvs::realserver::poolcounter_backends'),
) {
    $present_pools = $pools.keys()
    $services = wmflib::service::fetch(true).filter |$lvs_name, $svc| {$lvs_name in $present_pools}
    require ::lvs::configuration
    $ips = wmflib::service::get_ips_for_services($services, $::site)

    class { '::lvs::realserver':
        realserver_ips => $ips,
    }

    if $use_conftool {
        require ::profile::conftool::client
        # Install the python poolcounter client, if any backend is defined
        if $poolcounter_backends {
            $pc_ensure = 'present'
            $bc = $poolcounter_backends
            $all_nodes = $present_pools.map | $pool | { wmflib::service::get_pool_nodes($pool) }.flatten().unique()
            # Safeguard: act on 10% of the nodes at max, or 1 otherwise.
            $max_concurrency = max(floor(length($all_nodes) * 0.1), 1)
        } else {
            $pc_ensure = 'absent'
            $bc = []
            $max_concurrency = 0
        }
        class { 'poolcounter::client::python':
            ensure   => $pc_ensure,
            backends => $bc
        }
        $pools.map |$lvs_name, $pool| {
            $pool['services']
        }.flatten().unique().each |$service| {
            # Extract all the pools in which the service is included.
            $service_pools = $pools.filter |$lvs_name, $pool| { $service in $pool['services'] }
            conftool::scripts::safe_service_restart { $service:
                lvs_pools       => keys($service_pools),
                lvs_class_hosts => $::lvs::configuration::lvs_class_hosts,
                services        => $services,
                max_concurrency => $max_concurrency,
            }
        }
    }
}
