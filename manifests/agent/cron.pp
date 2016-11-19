# == Class pupmod::agent::cron
#
# This class configures the cron settings for a non-daemonized puppet
# client.
#
# == Parameters
#
# [*interval*]
# Type: Integer
# Default: 30
#
# The cron iteration time (in minutes) for running puppet.
# This applies the standard */$interval style syntax from cron.
# See crontab(5) for additional details.
#
# Note: This is overridden if $minute is set to anything other
# than 'nil'.  If this is the case, it is assumed that you want finer
# control over your puppet run.
#
# [*minute_base*]
# Type: String or Integer
# Default: $::ipaddress
# The default artifact to use to auto-generate a cron interval.
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
# [*run_timeframe*]
# Type: Integer
# Default: 60
#
# The time frame within which you wish to run the puppet agent. This
# directly translates to the minute field of the cron job so this
# should probably be left at 60.
#
# [*runs_per_timeframe*]
# Type: Integer
# Default: 2
#
# The number of times, per $timeframe, that you want to run the Puppet
# Agent.
#
# [*minute*]
# Type: Cron value
# Default: 'rand'
#
# The 'minute' value for the crontab entry.
# Set to 'nil' if you want to use $interval.
#
# [*hour*]
# Type: Cron value
# Default: '*'
#
# The 'hour' value for the crontab entry.
# Not used if using $interval.
#
# [*monthday*]
# Type: Cron value
# Default: '*'
#
# The 'monthday' value for the crontab entry.
# Not used if using $interval.
#
# [*month*]
# Type: Cron value
# Default: '*'
#
# The 'month' value for the crontab entry.
# Not used if using $interval.
#
# [*weekday*]
# Type: Cron value
# Default: '*'
#
# The 'weekday' value for the crontab entry.
# Not used if using $interval.
#
# [*maxruntime*]
# Type: Cron value
# Default: '*'
#
# This variable controls how long a run of puppet will be allowed to
# proceed by the puppet cron job before being forcibly overridden. By
# default, it will never be overridden.
#
# If not specified, this will be set to 4*interval or 4 hours,
# whichever is smaller.
#
class pupmod::agent::cron (
  $interval = '30',
  $minute_base = $::ipaddress,
  $run_timeframe = '60',
  $runs_per_timeframe = '2',
  $minute = 'rand',
  $hour = '*',
  $monthday = '*',
  $month = '*',
  $weekday = '*',
  $maxruntime = ''
  ) {
  validate_integer($interval)
  validate_string($minute_base)
  validate_integer($runs_per_timeframe)
  validate_integer($run_timeframe)


  include '::pupmod'

  cron { 'puppetd': ensure => 'absent' }

  if $minute == 'nil' {
    cron { 'puppetagent':
      command => '/usr/local/bin/puppetagent_cron.sh',
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
      command  => '/usr/local/bin/puppetagent_cron.sh',
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
