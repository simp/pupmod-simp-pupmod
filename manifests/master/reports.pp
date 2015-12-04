# == Class: pupmod::master::reports
#
# This class simply controls settings around client reports on the
# system.
#
# Most importantly, it allows for purging the reports.
#
# == Parameters
#
# [*purge*]
# Type: Boolean
# Default: true
#   Whether or not to purge old reports from the system.
#
# [*purge_keep_days*]
# Type: Integer
# Default: 7
#   The number of days of reports to keep around on the system.
#
# [*purge_verbose*]
# Type: Boolean
# Default: false
#   Whether or not to be verbose about which logs are being purged.
#
# == Authors
#  * Trevor Vaughan <tvaughan@onyxpoint.com>
#
class pupmod::master::reports (
  $port = $::pupmod::master::masterport,
  $purge = true,
  $purge_keep_days = '7',
  $purge_verbose = false
) {
  validate_bool($purge)
  validate_integer($purge_keep_days)
  validate_bool($purge_verbose)

  if $purge {
    if $purge_verbose {
      $l_purge_script = "/bin/find /var/lib/puppet/reports/ -mtime +${purge_keep_days} -type f -exec echo \"Removing {}\" \\; -exec rm -f {} \\;"
    }
    else {
      $l_purge_script = "/bin/find /var/lib/puppet/reports/ -mtime +${purge_keep_days} -type f -exec rm -f {} \\;"
    }

    file { '/etc/cron.daily/puppet_client_report_purge':
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      content => "#!/bin/sh\n${l_purge_script}"
    }
  }
}
