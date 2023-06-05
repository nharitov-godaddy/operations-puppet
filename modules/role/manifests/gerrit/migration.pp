# temp allow rsyncing gerrit data to new server
class role::gerrit::migration {

    system::role {'gerrit::migration':
        description => 'temp role to allow migrating Gerrit data to a new server',
    }

    include ::profile::base::production
    include ::profile::firewall
    include ::profile::gerrit::migration_base
    include ::profile::gerrit::migration
}
