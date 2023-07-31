# This class configures the scheduled run settings for a non-daemonized puppet client
#
# Note: The parameters are present for backwards compatibility, at some point,
# this class will be renamed to reflect that it is now a systemd timer.
#
# @param enable
#   Enable, or disable, the scheduled agent run
#
# @param interval
#   The cron iteration time (in minutes) for running puppet
#
#   * When ``$minute`` is set to 'nil', this applies the standard
#     ``*/$interval`` style syntax from cron for the minute field.
#     See ``crontab(5)`` for additional details.
#
#   * Otherwise, this value is ignored.
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
#   * Not used if using ``$interval``
#
# @param run_timeframe
#   The time frame within which you wish to run the puppet agent
#
#   * This directly translates to the minute field of the cron job so this
#     should probably be left at 60
#
#   * Not used if using ``$interval``
#
# @param runs_per_timeframe
#   The number of times, per ``$timeframe``, that you want to run the Puppet
#   Agent.
#
#   * Not used if using ``$interval``
#
# @param systemd_calendar
#   The exact systemd calendar string to add to the timer
#
#   * This is **not** checked for correctess
#
# @param minute
#   The ``minute`` value for the crontab entry
#
#   Set to ``nil`` if you want to only use ``$interval``.
#
#   Set to one of the randiomization algorithms if you want the minute
#   to be auto-generated from ``$minute_base``:
#
#   ``ip_mod`` or its backward-compatible alias ``rand`` uses a
#   IP-modulus-based transformation of the numeric IP representation of
#   ``$minute_base``, when ``$minute_base`` is an IP address.
#   Otherwise, it uses a crc32-based transformation of $minute_base.
#   This algorithm works well when the number of hosts managed by a
#   Puppet master exceeds 60 and the hosts have linearly-assigned IP
#   addresses.
#
#   ``sha256`` uses a SHA256-based transformation ``$minute_base``.
#   This algorithm provides general randomization for cases in which
#   ``ip_mod`` yields undesirable clustering.
#
# @param hour
#   The ``hour`` value for the crontab entry
#
#   * Not used if using ``$interval``
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
#   * When not set, an appropriate value is computed based on
#     cron frequency and ``$maxruntime``.
#
# @example Configure puppet agent cron to run every 20 minutes
#
#   class { 'pupmod::agent::cron:
#     interval => 20,
#     minute   => 'nil'
#   }
#
# @example Configure puppet agent cron to run once an hour using
#   the default minute randomization algorithm
#
#   class { 'pupmod::agent::cron:
#     runs_per_timeframe => 1
#   }
#
# @example Configure cron to run once per day at a particular time
#
#   class { 'pupmod::agent::cron:
#     minute => '23'
#     hour   => '4'
#   }
#
class pupmod::agent::cron (
  Boolean                                                             $enable             = true,
  Integer[0]                                                          $interval           = 30,
  String                                                              $minute_base        = $facts['networking']['ip'],
  Integer[0]                                                          $run_timeframe      = 60,
  Integer[0]                                                          $runs_per_timeframe = 2,
  Optional[String[1]]                                                 $systemd_calendar   = undef,
  Variant[Simplib::Cron::Minute,Enum['nil','ip_mod','rand','sha256']] $minute             = 'ip_mod',
  Simplib::Cron::Hour                                                 $hour               = '*',
  Simplib::Cron::MonthDay                                             $monthday           = '*',
  Simplib::Cron::Month                                                $month              = '*',
  Simplib::Cron::Weekday                                              $weekday            = '*',
  Integer[1]                                                          $maxruntime         = 240,
  Boolean                                                             $break_puppet_lock  = true,
  Optional[Integer[1]]                                                $max_disable_time   = undef
) {
  include 'pupmod'

  # Remove legacy cron jobs
  cron { ['puppetd', 'puppetagent']: ensure => 'absent' }

  case $minute {
    # rand = ip_mod for backward compatibility
    'ip_mod', 'rand' : {
      $_max_disable_base = $maxruntime + ($run_timeframe / $runs_per_timeframe)
      $_minute           = simplib::rand_cron($minute_base,'ip_mod',$runs_per_timeframe,$run_timeframe - 1)
    }
    'sha256' : {
      $_max_disable_base = $maxruntime + ($run_timeframe / $runs_per_timeframe)
      $_minute           = simplib::rand_cron($minute_base,'sha256',$runs_per_timeframe,$run_timeframe - 1)
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
    $_splaylimit = getvar('pupmod::splaylimit')

    if $_splaylimit {
      # This assumes splay is in seconds.
      $_max_disable_time = $_max_disable_base + ($_splaylimit / 60)
    }
    else {
      $_max_disable_time = $_max_disable_base
    }
  }

  if $systemd_calendar {
    $_systemd_calendar = $systemd_calendar
  }
  elsif $minute == 'nil' {
    $_systemd_calendar = simplib::cron::to_systemd($_minute)
  }
  else {
    $_systemd_calendar = simplib::cron::to_systemd(
      $_minute,
      $hour,
      $month,
      $monthday,
      $weekday
    )
  }

  file { '/usr/local/bin/puppetagent_cron.sh':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0750',
    content => epp("${module_name}/usr/local/bin/puppetagent_cron")
  }

  $_timer = @("EOM")
  [Timer]
  OnCalendar=${_systemd_calendar}
  | EOM

  $_service = @("EOM")
  [Service]
  Type=oneshot
  SuccessExitStatus=2
  ExecStart=/usr/local/bin/puppetagent_cron.sh
  | EOM

  systemd::timer { 'puppet_agent.timer':
    timer_content   => $_timer,
    service_content => $_service,
    active          => $enable,
    enable          => $enable,
    require         => File['/usr/local/bin/puppetagent_cron.sh']
  }

  file { '/usr/local/bin/careful_puppet_service_shutdown.sh':
    ensure  => 'file',
    mode    => '0750',
    owner   => 'root',
    group   => 'root',
    content => epp("${module_name}/usr/local/bin/careful_puppet_service_shutdown")
  }

# If cron is enabled make sure puppet service is disabled.  Start in background
# because disabling puppet service will kill all instances of puppet running.
# See https://tickets.puppetlabs.com/browse/PUP-1320 for more information
  if $facts['puppet_service_enabled'] or $facts['puppet_service_started'] {
    exec { 'careful_puppet_service_shutdown':
      command => '/usr/local/bin/careful_puppet_service_shutdown.sh &',
      require => File['/usr/local/bin/careful_puppet_service_shutdown.sh']
    }
  }
}
