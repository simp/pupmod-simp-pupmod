# This class provides the sysconfig settings for the puppetserver daemon.
#
# @param java_bin
#  Type: Absolute Path
#  Default: '/usr/bin/java'
#
#  The path to the java executable that the Puppet server should use on the
#  system.
#
# @param java_start_memory
#  Type: Integer followed by one of 'k', 'm', or 'g' for kilobytes, megabytes,
#        and gigabytes respectively.
#  Default: '2g'
#
#  The amount of memory to allocate on service startup.
#
# @param java_max_memory
#  Type: Integer followed by one of '%', 'k', 'm', or 'g' for a percentage of
#        total memory, kilobytes, megabytes, and gigabytes respectively.
#  Default: '50%'
#
#  The maximum amount of memory to allocate within the system.
#
# @param java_temp_dir
#  Type: Absolute Path
#  Default: '$::pupmod::vardir/pserver_tmp'
#
#  The temporary directory to be used for periodic executables. This should not
#  be /tmp, /var/tmp, or /dev/shm on SIMP systems due to the default disabling
#  of exec on those spaces.
#
#  Note: Preceeding directories will not be created.
#
# @param java_extra_args
#   An array that will be joined and appended to the Java argument list. The
#   sanity and syntax of this list will not be checked.
#
# @param service_stop_retries
#   The number of times to attempt to stop the puppetserver process before
#   failing.
#
# @param start_timeout
#   The number of seconds after which the service will be determined to have
#   failed to start.
#
class pupmod::master::sysconfig (
  Stdlib::AbsolutePath           $install_dir          = $::pupmod::params::master_install_dir,
  Stdlib::AbsolutePath           $config               = $::pupmod::master::confdir,
  Array[Stdlib::AbsolutePath]    $bootstrap_config     = $::pupmod::params::master_bootstrap_config,
  Stdlib::AbsolutePath           $java_bin             = '/usr/bin/java',
  Optional[Pupmod::Memory]       $java_start_memory    = undef,
  Pupmod::Memory                 $java_max_memory      = '50%',
  Optional[Stdlib::AbsolutePath] $java_temp_dir        = undef,
  Optional[Array[String]]        $extra_java_args      = undef,
  Integer                        $service_stop_retries = 60,
  Integer                        $start_timeout        = 120
) inherits ::pupmod::master {

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
