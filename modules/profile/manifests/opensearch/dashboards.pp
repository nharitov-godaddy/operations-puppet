# SPDX-License-Identifier: Apache-2.0
# == Class: profile::opensearch::dashboards
class profile::opensearch::dashboards (
  Enum['1']         $config_version     = lookup('profile::opensearch::dashboards::config_version',     { 'default_value' => '1' }),
  Boolean           $enable_backups     = lookup('profile::opensearch::dashboards::enable_backups',     { 'default_value' => false }),
  String            $package_name       = lookup('profile::opensearch::dashboards::package_name',       { 'default_value' => 'opensearch-dashboards' }),
  Optional[Boolean] $tile_map_enabled   = lookup('profile::opensearch::dashboards::tile_map_enabled',   { 'default_value' => undef }),
  Optional[Boolean] $region_map_enabled = lookup('profile::opensearch::dashboards::region_map_enabled', { 'default_value' => undef }),
  Optional[String]  $index              = lookup('profile::opensearch::dashboards::index',              { 'default_value' => undef }),
  Optional[Boolean] $enable_warnings    = lookup('profile::opensearch::dashboards::enable_warnings',    { 'default_value' => undef }),
) {
  class { 'opensearch_dashboards':
    config_version     => $config_version,
    package_name       => $package_name,
    enable_backups     => $enable_backups,
    tile_map_enabled   => $tile_map_enabled,
    region_map_enabled => $region_map_enabled,
    index              => $index,
    enable_warnings    => $enable_warnings,
  }

  package { [
    'securityDashboards',        # cannot run when security plugin is disabled
    'indexManagementDashboards', # can cause accidental complete data loss - needs working security settings
    'notificationsDashboards',   # servers are firewalled off from reaching targets
    'alertingDashboards',        # requires notification capabilities - see ^^
    'observabilityDashboards',   # needs further investigation to limit write access via ui
  ]:
    ensure   => 'absent',
    provider => 'opensearch_dashboards_plugin',
  }

  if ($enable_backups) {
    include profile::backup::host

    backup::set { 'opensearch-dashboards':
      jobdefaults => 'Daily-productionEqiad', # full backups every day
    }
  }
}
