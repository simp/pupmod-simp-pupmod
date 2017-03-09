# This class configures the cron settings for a non-daemonized puppet client
#
# @param interval
#   The cron iteration time (in minutes) for running puppet
#
#   * This applies the standard ``*/$interval`` style syntax from cron
#
#   * See ``crontab(5)`` for additional details
#
#   * NOTE: This is overridden if ``$minute`` is set to anything other than
#     ``nil`` or ``rand``.  If this is the case, it is assumed that you want
#     finer control over your puppet run.
#
# @param minute_base
#   The default artifact to use to auto-generate a cron interval
#
#   * The default of ``$::ipaddress`` is used to provide a reasonable guess at
#     spreading the puppet runs across all of your systems. However, you can
#     set this to *anything* that you like.
#
#   * Use ``$::ipaddress_eth0`` to generate the entry from the eth0 IP Address
#
#   * Use ``$::uniqueid`` to generate the entry from the system UUID
#
#   * WARNING: If this is the *same* resolved value on all of your systems then
#     your systems will have the *same* run interval.
#
# @param run_timeframe
#   The time frame within which you wish to run the puppet agent
#
#   * This directly translates to the minute field of the cron job so this
#     should probably be left at 60
#
# @param runs_per_timeframe
#   The number of times, per ``$timeframe``, that you want to run the Puppet
#   Agent.
#
# @param minute
#   The ``minute`` value for the crontab entry
#
#   Set to ``nil`` if you want to use $interval
#
# @param hour
#   The ``hour`` value for the crontab entry
#
#   Not used if using ``$interval``
#
# @param monthday
#   The ``monthday`` value for the crontab entry
#
#   * Not used if using ``$interval``
#
# @param month
#   The ``month`` value for the crontab entry
#
#   * Not used if using ``$interval``
#
# @param weekday
#   The ``weekday`` value for the crontab entry
#
#   * Not used if using ``$interval``
#
# @param maxruntime
#   How long (in minutes) a puppet agent will be allowed to run before being
#   forcibly stopped
#
# @param break_puppet_lock
#   Forcibly enable the puppet agent if it has been disabled for
#   ``$max_disable_time``
#
#   * This is enabled by default so that the system can remain in a
#     self-healing state
#
# @param max_disable_time
#   How long (in minutes) a puppet agent will be allowed to remain disabled
#   before being forcibly enabled
#
#   * This only takes effect if ``$break_puppet_lock`` is true
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
  Integer[1]            $maxruntime         = 240,
  Boolean               $break_puppet_lock  = true,
  Optional[Integer[1]]  $max_disable_time   = undef
) {

  include '::pupmod'

  cron { 'puppetd': ensure => 'absent' }

  case $minute {
    'rand'  : {
      $_max_disable_base = $maxruntime + ($run_timeframe / $runs_per_timeframe)
      $_minute           = rand_cron($minute_base,$runs_per_timeframe,$run_timeframe)
    }
    'nil'   : {
      $_max_disable_base = $maxruntime + $interval
      $_minute           = "*/${interval}"
    }
    default : {
      $_max_disable_base = $maxruntime + $interval
      $_minute           = $minute
    }
  }

  if $max_disable_time {
    $_max_disable_time = $max_disable_time
  }
  else {
    if $::splaylimit {
      # This assumes splay is in seconds.
      $_max_disable_time = $_max_disable_base + ($::splaylimit / 60)
    }
    else {
      $_max_disable_time = $_max_disable_base
    }
  }

  if $minute == 'nil' {
    cron { 'puppetagent':
      command => '/usr/local/bin/puppetagent_cron.sh',
      user    => 'root',
      minute  => $_minute,
      require => File['/usr/local/bin/puppetagent_cron.sh']
    }
  }
  else {
    cron { 'puppetagent':
      command  => '/usr/local/bin/puppetagent_cron.sh',
      user     => 'root',
      minute   => $_minute,
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
