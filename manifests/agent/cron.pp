# This class configures the cron settings for a non-daemonized puppet
# client.
#
# @param interval
#   The cron iteration time (in minutes) for running puppet.
#   This applies the standard */$interval style syntax from cron.
#   See crontab(5) for additional details.
#
#   Note: This is overridden if $minute is set to anything other
#   than 'nil'.  If this is the case, it is assumed that you want finer
#   control over your puppet run.
#
# @param minute_base
#   The default artifact to use to auto-generate a cron interval.
#
# The default of $::ipaddress is used to provide a reasonable guess at
# spreading the puppet runs across all of your systems. However, you
# can set this to *anything* that you like.
#
# Use $::ipaddress_eth0 to generate the entry from the eth0 IP Address
# Use $::uniqueid to generate the entry from the system UUID
#
# If this is the *same* resolved value on all of your systems then
# your systems will have the *same* run interval.
#
# @param run_timeframe
#   The time frame within which you wish to run the puppet agent. This
#   directly translates to the minute field of the cron job so this
#   should probably be left at 60.
#
# @param runs_per_timeframe
#   The number of times, per $timeframe, that you want to run the Puppet
#   Agent.
#
# @param minute
#   The 'minute' value for the crontab entry.
#   Set to 'nil' if you want to use $interval.
#
# @param hour
#   The 'hour' value for the crontab entry.
#   Not used if using $interval.
#
# @param monthday
#   The 'monthday' value for the crontab entry.
#   Not used if using $interval.
#
# @param month
#   The 'month' value for the crontab entry.
#   Not used if using $interval.
#
# @param weekday
#   The 'weekday' value for the crontab entry.
#   Not used if using $interval.
#
# @param maxruntime
#   This variable controls how long a run of puppet will be allowed to
#   proceed by the puppet cron job before being forcibly overridden. By
#   default, it will never be overridden.
#
#   If not specified, this will be set to 4*interval or 4 hours,
#   whichever is smaller.
#
class pupmod::agent::cron (
  Integer[0]            $interval           = 30,
  String                $minute_base        = $facts['ipaddress'],
  Integer[0]            $run_timeframe      = 60,
  Integer[0]            $runs_per_timeframe = 2,
  Variant[Array,String] $minute             = 'rand',
  Variant[Array,String] $hour               = '*',
  Variant[Array,String] $monthday           = '*',
  Variant[Array,String] $month              = '*',
  Variant[Array,String] $weekday            = '*',
  Optional[Integer[0]]  $maxruntime         = undef
) {

  include '::pupmod'

  cron { 'puppetd': ensure => 'absent' }

  if $minute == 'nil' {
    cron { 'puppetagent':
      command => 'flock -w .1 /var/puppetagent_cron.lock /usr/local/bin/puppetagent_cron.sh',
      user    => 'root',
      minute  => "*/${interval}",
      require => File['/usr/local/bin/puppetagent_cron.sh']
    }
  }
  else {
    if $minute == 'rand' {
      $l_minute = rand_cron($minute_base,$runs_per_timeframe,$run_timeframe)
    }
    else {
      $l_minute = $minute
    }
    cron { 'puppetagent':
      command  => 'flock -w .1 /var/puppetagent_cron.lock /usr/local/bin/puppetagent_cron.sh',
      user     => 'root',
      minute   => $l_minute,
      hour     => $hour,
      monthday => $monthday,
      month    => $month,
      weekday  => $weekday,
      require  => File['/usr/local/bin/puppetagent_cron.sh']
    }
  }

  file { '/usr/local/bin/puppetagent_cron.sh':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0750',
    content => template('pupmod/usr/local/bin/puppetagent_cron.erb')
  }
}
