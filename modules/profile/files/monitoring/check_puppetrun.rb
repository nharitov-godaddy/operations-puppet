#!/usr/bin/ruby

# A simple nagios check that should be run as root an
# can check when the last run was done of puppet.
# It can also check fail counts and skip machines
# that are not enabled
#
# The script will use the puppet last_run-summary.yaml
# file to determine when last Puppet ran

require 'fileutils'
require 'optparse'
require 'puppet'
require 'yaml'

PRINT_FAILED_RESOURCES_NO = 3 # Number of failed resources to print. Don't set this high
Puppet.initialize_settings

runlockfile = Puppet.settings[:agent_catalog_run_lockfile]
adminlockfile = Puppet.settings[:agent_disabled_lockfile]
summaryfile = Puppet.settings[:lastrunfile]
reportfile = Puppet.settings[:lastrunreport]
icingafile = "/var/lib/puppet/state/icinga_puppet_fail.lock"
enabled = true
alert_master_fail = false
lastrun = 0
failcount = 0
warn = 0
crit = 0
disable_grace = 86_400  # 24 hours
disable_crit = 604_800  # 1 week
fail_grace = 86_400  # 24 hours
enabled_only = false
# init variable
first_fail_time = Time.now

opt = OptionParser.new

opt.on("--critical [CRIT]", "-c", Integer, "Critical staleness threshold, time in seconds") do |f|
    crit = f.to_i
end

opt.on("--warn [WARN]", "-w", Integer, "Warning staleness threshold, time in seconds") do |f|
    warn = f.to_i
end

opt.on("--only-enabled", "-e", "Only alert if Puppet is enabled") do
    enabled_only = true
end

opt.on("--runlock-file [FILE]", "-l", "Location of the run lock file, default #{runlockfile}") do |f|
    runlockfile = f
end

opt.on("--adminlock-file [FILE]", "-a", "Location of the admin lock file, default #{adminlockfile}") do |f|
    adminlockfile = f
end

opt.on("--summary-file [FILE]", "-s", "Location of the summary file, default #{summaryfile}") do |f|
    summaryfile = f
end

opt.on("--report-file [FILE]", "-r", "Location of the report file, default #{reportfile}") do |f|
    reportfile = f
end

opt.on("--alert-master-fail", "Alert on failures related to Puppet master issues") do
    alert_master_fail = true
end

opt.on("--disable-grace", "Number of seconds a host can be disabled before alerting. default: #{disable_grace}") do |f|
    disable_grace = f.to_i
end

opt.on("--disable-critical", "Number of seconds a host can be disabled before alerting. default: #{disable_crit}") do |f|
    disable_crit = f.to_i
end

opt.on("--fail-grace", "Number of seconds before a puppet failure is CRITICAL instead of WARNING. default: #{fail_grace}") do |f|
    fail_grace = f
end

opt.parse!

if warn.zero? || crit.zero?
    puts "Please specify a warning and critical level"
    exit 3
end

if File.exists?(adminlockfile)
       enabled = false
       disabled_message = YAML.safe_load(File.read(adminlockfile))["disabled_message"]
       disabled_time = File.stat(adminlockfile).ctime
end

if File.exists?(summaryfile)
    begin
      summary = YAML.safe_load(File.read(summaryfile))
      lastrun = summary["time"]["last_run"]

        # machines that outright failed to run like on missing dependencies
        # are treated as huge failures. The yaml file will be valid but
        # it wont have anything but last_run in it
      if summary.include?("events")
          failcount = summary["events"]["failure"]
      else
          failcount = :failed
      end

      if failcount.zero? && summary["resources"]["total"].zero?
          # When Puppet fails due to a dependency cycle all counters are zero, treat it as a failure.
          failcount = :failed_no_resources
      end
    rescue
        failcount = :failed_to_parse_summary_file
    end
else
    failcount = :no_summary_file
end

if failcount.is_a?(Symbol)
  FileUtils.touch(icingafile) unless File.exist?(icingafile)
  first_fail_time = File.stat(icingafile).ctime
elsif File.exist?(icingafile)
  # successful puppet run make sure we clean up any old files
  File.delete(icingafile)
end

def time_ago(s)
  units = {
    24 * 60 * 60 => 'day',
    60 * 60      => 'hour',
    60           => 'minute',
    1            => 'second',
  }
  if s.zero?
    return "0 seconds"
  end
  units.sort.reverse.each do |len, unit|
    return "#{s / len} #{unit}#{'s' if s / len > 1}" if s >= len
  end
  "Indeterminate amount of time (see time_ago)"
end
if alert_master_fail || first_fail_time - fail_grace > Time.now
  STATUS = 'CRITICAL'
  EXIT = 2
else
  STATUS = 'WARNING'
  EXIT = 1
end
if failcount == :failed_no_resources
    puts STATUS + ": Failed to apply catalog, zero resources tracked by Puppet. " +
         "Could be an interrupted request or a dependency cycle."
    exit EXIT
end

if failcount == :failed
    puts STATUS + ": Catalog fetch fail. " +
         "Either compilation failed or puppetmaster has issues"
    exit EXIT
end

if failcount == :failed_to_parse_summary_file || failcount == :no_summary_file
    puts "UNKNOWN: Failed to check. Reason is: #{failcount}"
    exit 3
end

time_since_last_run = Time.now.to_i - lastrun
human_time_since_last_run = time_ago(time_since_last_run)

if enabled == false && (enabled_only || disabled_time + disable_grace > Time.now)
    puts "OK: Puppet is currently disabled (#{disabled_message}), not alerting. " +
         "Last run #{human_time_since_last_run} ago with #{failcount} failures"
    exit 0
end

unless enabled
  disabled_for = (Time.now - disabled_time).to_i
  if disabled_for > disable_crit
      exit_code = 2
      status = 'CRITICAL'
  else
      exit_code = 1
      status = 'WARNING'
  end
  puts "#{status}: Puppet has been disabled for #{disabled_for} seconds, " +
       "message: #{disabled_message}, " +
       "last run #{human_time_since_last_run} ago with #{failcount} failures"
  exit exit_code
end

if failcount > 0 # rubocop:disable Style/NumericPredicate
  report = YAML.safe_load(File.read(reportfile), [Puppet::Transaction::Report])
  failed_resources = report.resource_statuses.select { |_, r| r.failed }.map { |_, r| r.resource }
  failed_resources = failed_resources[0..PRINT_FAILED_RESOURCES_NO]
  puts "WARNING: Puppet has #{failcount} failures. " +
      "Last run #{human_time_since_last_run} ago with #{failcount} failures. " +
      "Failed resources (up to #{PRINT_FAILED_RESOURCES_NO} shown): #{failed_resources.join','}"
  exit 1
end

if time_since_last_run >= crit
    puts "CRITICAL: Puppet last ran #{human_time_since_last_run} ago"
    exit 2
end

if time_since_last_run >= warn
    puts "WARNING: Puppet last ran #{human_time_since_last_run} ago"
    exit 1
end

puts "OK: Puppet is currently enabled, " +
     "last run #{human_time_since_last_run} ago with #{failcount} failures"
exit 0
