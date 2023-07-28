# SPDX-License-Identifier: Apache-2.0
# === Class profile::docker::runner
#
# Allows to run multiple applications via docker containers.
#
# === Parameters
#
# [*service_defs*] An Hash of definitions for service::docker resources
#
# === Examples
#
# Example: in order to run mathoid, the hiera configuration will look
# like what follows:
#
# profile::docker::runner::service_defs:
#   mathoid:
#     port: 100044
#     version: build-42
#     override_cmd: nodejs server.js -c /etc/mathoid/config.yaml
#     config:
#       num_workers: 1
#       worker_heap_limit_mb: 300
#       ... [all the config should go here]
#
class profile::docker::runner(
    $service_defs = lookup('profile::docker::runner::service_defs')
) {
    require ::profile::docker::engine
    $service_defs.each |$svc_name, $svc_params| {
        service::docker { $svc_name:
            * => $svc_params,
        }
    }

    # Configure rsyslog to ingest logs from containers so they can be forwarded to kafka/logstash.
    rsyslog::input::file { 'docker-json':
        path               => '/var/lib/docker/containers/*/*-json.log',
        reopen_on_truncate => 'on',
        addmetadata        => 'on',
        addceetag          => 'on',
        syslog_tag         => 'docker',
        priority           => 8,
    }
}
