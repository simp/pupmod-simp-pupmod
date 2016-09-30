# Class: pupmod::master::sysconfig
#
# This class provides the sysconfig settings for the puppetserver daemon.
#
# == Variables ==
#
# [*java_bin*]
#  Type: Absolute Path
#  Default: '/usr/bin/java'
#
#  The path to the java executable that the Puppet server should use on the
#  system.
#
# [*java_start_memory*]
#  Type: Integer followed by one of 'k', 'm', or 'g' for kilobytes, megabytes,
#        and gigabytes respectively.
#  Default: '2g'
#
#  The amount of memory to allocate on service startup.
#
# [*java_max_memory*]
#  Type: Integer followed by one of '%', 'k', 'm', or 'g' for a percentage of
#        total memory, kilobytes, megabytes, and gigabytes respectively.
#  Default: '50%'
#
#  The maximum amount of memory to allocate within the system.
#
# [*java_temp_dir*]
#  Type: Absolute Path
#  Default: '$::pupmod::vardir/pserver_tmp'
#
#  The temporary directory to be used for periodic executables. This should not
#  be /tmp, /var/tmp, or /dev/shm on SIMP systems due to the default disabling
#  of exec on those spaces.
#
#  Note: Preceeding directories will not be created.
#
# [*java_extra_args*]
#  Type: Array of Strings
#  Default: []
#
#  An array that will be joined and appended to the Java argument list. The
#  sanity and syntax of this list will not be checked.
#
# [*service_stop_retries*]
#  Type: Integer
#  Default: 60
#
#  The number of times to attempt to stop the puppetserver process before
#  failing.
#
# [*start_timeout*]
#  Type: Integer
#  Default: 120
#
#  The number of seconds after which the service will be determined to have
#  failed to start.
#
class pupmod::master::sysconfig (
  $install_dir = $::pupmod::params::master_install_dir,
  $config = $::pupmod::master::confdir,
  $bootstrap_config = $::pupmod::params::master_bootstrap_config,
  $java_bin = '/usr/bin/java',
  $java_start_memory = '',
  $java_max_memory = '50%',
  $java_temp_dir = '',
  $extra_java_args = [],
  $service_stop_retries = '60',
  $start_timeout = '120'
) inherits ::pupmod::master {

  validate_absolute_path($java_bin)
  if !empty($java_start_memory){ validate_re($java_start_memory,'^\d+(g|k|m)$') }
  validate_re($java_max_memory,'^\d+(g|k|m|%)$')
  if !empty($java_temp_dir) { validate_absolute_path($java_temp_dir) }
  validate_array($extra_java_args)
  validate_integer($service_stop_retries)
  validate_integer($start_timeout)

  compliance_map()

  if empty($java_temp_dir) {
    $_java_temp_dir = "${::pupmod::vardir}/pserver_tmp"
  }
  else {
    $_java_temp_dir = $java_temp_dir
  }

  file { $_java_temp_dir:
    ensure => 'directory',
    owner  => 'puppet',
    group  => 'puppet',
    mode   => '0750'
  }

  file { '/etc/sysconfig/puppetserver':
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => template('pupmod/etc/sysconfig/puppetserver.erb'),
    notify  => Service[$::pupmod::master::service]
  }
}
