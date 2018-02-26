# This class simply controls settings around client reports on the system.
#
# Most importantly, it allows for purging the reports.
#
# @param port
#   The port upon which to listen for reports.
#
# @param vardir
#   The directory where reports should be stored.
#
# @param purge
#   Whether or not to purge old reports from the system.
#
# @param purge_keep_days
#   The number of days of reports to keep around on the system.
#
# @param purge_verbose
#   Whether or not to be verbose about which logs are being purged.
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class pupmod::master::reports (
  Simplib::Port        $port            = $::pupmod::master::masterport,
  Stdlib::AbsolutePath $vardir          = $::pupmod::master::vardir,
  Boolean              $purge           = true,
  Integer              $purge_keep_days = 7,
  Boolean              $purge_verbose   = false
) inherits ::pupmod::master {

  assert_private()

  if $purge {
    if $purge_verbose {
      $l_purge_script = "/bin/find ${vardir}/reports/ -mtime +${purge_keep_days} -type f -exec echo \"Removing {}\" \\; -exec rm -f {} \\;"
    }
    else {
      $l_purge_script = "/bin/find ${vardir}/reports/ -mtime +${purge_keep_days} -type f -exec rm -f {} \\;"
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
