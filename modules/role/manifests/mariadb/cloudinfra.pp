# This role is to be used for the `cloudinfra` VPS project instances.
# It currently hosts the labspuppet database used for Cloud VPS Puppet
# ENC API, and may hold others in future.
class role::mariadb::cloudinfra (
    Boolean $master = false,
) {
    system::role { 'mariadb::cloudinfra':
        description => 'Cloudinfra database',
    }

    $mysql_role = $master ? {
        true  => 'master',
        false => 'slave',
    }

    include ::profile::base::production
    include ::profile::mariadb::monitor
    include ::profile::firewall

    include ::profile::mariadb::monitor::prometheus

    include ::profile::mariadb::grants::cloudinfra
    class { '::profile::mariadb::cloudinfra':
        master => $master,
    }
}
