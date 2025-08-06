# This class simply controls settings around client reports on the system.
#
# Most importantly, it allows for purging the reports.
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
#   DEPRECATED
#
#   * See the systemd tmpfiles logs for details
#
# @param port
#   DEPRECATED
#
# @author https://github.com/simp/pupmod-simp-pupmod/graphs/contributors
#
class pupmod::master::reports (
  Stdlib::AbsolutePath    $vardir          = $pupmod::master::vardir,
  Boolean                 $purge           = true,
  Integer                 $purge_keep_days = 7,
  Optional[Boolean]       $purge_verbose   = undef,
  Optional[Simplib::Port] $port            = undef
) inherits pupmod::master {
  assert_private()

  # Remove this when the deprecated options above are removed
  file { '/etc/cron.daily/puppet_client_report_purge': ensure => 'absent' }

  $_ensure = $purge ? { true => 'present', default => 'absent' }

  systemd::tmpfile { 'purge_puppetserver_reports.conf':
    ensure  => $_ensure,
    content => "e ${vardir}/reports - - - ${purge_keep_days}d",
  }
}
