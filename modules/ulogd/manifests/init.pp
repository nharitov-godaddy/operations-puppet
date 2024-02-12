# SPDX-License-Identifier: Apache-2.0
# @summary Set up and configure ulogd2
#
# @param logfile
#    Where to send the daemon [i.e. not the NFLOG] logs
#    options are syslog, stdout, stderr or a file path
# @param log_level
#  The logging level for ulogd logs
# @param logemu_logfile
#  file to use for LOGEM output
# @param logemu_nfct_logfile
#  file to use for LOGEM nfct output
# @param oprint_logfile
#  file to use for OPRIN output
# @param gprint_logfile
#  file to use for GPRIN output
# @param xml_directory
#  file to use for xml files
# @param json_logfile
#  file to use for json output
# @param json_nfct_logfile
#  file to use for json nfct output
# @param pcap_file
#  file to use for libpcap output
# @param nacct_file
#  file to use for nacct output
# @param config_file
#  location of the main config file
# @param syslog_facility
#  facility to use with syslog extension
# @param syslog_level
#  log level to use with syslog extension
# @param sync
# If true sync all disk writes to disk immediately 
# @param nflog
#  outputters to use for NFLOG
# @param nfct
#  outputters to use for NFCT
# @param acct
#  outputters to use for NACCT
#
class ulogd (
  Wmflib::Ensure              $ensure              = present,
  Ulogd::Logfile              $logfile             = 'syslog',
  Wmflib::Syslog::Level::Unix $log_level           = 'info',
  Stdlib::Unixpath            $logemu_logfile      = '/var/log/ulog/syslogemu.log',
  Stdlib::Unixpath            $logemu_nfct_logfile = '/var/log/ulog/syslogemu_nfct.log',
  Stdlib::Unixpath            $oprint_logfile      = '/var/log/ulog/oprint.log',
  Stdlib::Unixpath            $gprint_logfile      = '/var/log/ulog/gprint.log',
  Stdlib::Unixpath            $xml_directory       = '/var/log/ulog/',
  Stdlib::Unixpath            $json_logfile        = '/var/log/ulog/ulogd.json',
  Stdlib::Unixpath            $json_nfct_logfile   = '/var/log/ulog/ulogd_nfct.json',
  Stdlib::Unixpath            $pcap_file           = '/var/log/ulog/ulogd.pcap',
  Stdlib::Unixpath            $nacct_file          = '/var/log/ulog/nacct.log',
  Stdlib::Unixpath            $config_file         = '/etc/ulogd.conf',
  Ulogd::Facility             $syslog_facility     = 'local7',
  Wmflib::Syslog::Level::Unix $syslog_level        = 'info',
  Boolean                     $sync                = true,
  Array[Ulogd::Output]        $nflog               = ['SYSLOG'],
  Array[Ulogd::Output]        $nfct                = [],
  Array[Ulogd::Output]        $acct                = [],
) {
  # An array of supported extensions that require additional packages
  # dbi, mysql, pgsql and sqlite are options for the future
  $supported_extensions = ['JSON', 'PCAP']

  package { 'ulogd2':
      ensure => stdlib::ensure($ensure, 'package')
  }

  $supported_extensions.each |String $extension| {
    if $extension in union($nflog, $nfct, $acct)  {
      ensure_packages("ulogd2-${extension.downcase}", {
        ensure  => $ensure,
      })
    }
  }
  file {$config_file:
    ensure  => stdlib::ensure($ensure, 'file'),
    content => template('ulogd/etc/ulogd.conf.erb'),
    notify  => Service['ulogd2'],
  }
  service {'ulogd2':
    ensure  => stdlib::ensure($ensure, 'service'),
    enable  => true,
    require => Package['ulogd2'],
  }

  profile::auto_restarts::service { 'ulogd2':
    ensure  => $ensure,
  }
}
