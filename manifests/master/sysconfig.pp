# This class provides the sysconfig settings for the ``puppetserver`` daemon.
#
# @param install_dir
#   The installation directory for the ``puppetserver``.
#
# @param config
#   The configuration directory for the ``puppetserver``.
#
# @param bootstrap_config
#   The bootstrap configuration directory for the ``puppetserver``.
#
# @param java_bin
#   The path to the java executable that the Puppet server should use on the
#   system.
#
# @param java_start_memory
#   The amount of memory to allocate on service startup.
#
# @param java_max_memory
#   The maximum amount of memory to allocate within the system.
#
# @param jruby_jar
#   The name of the jar file located in /opt/puppetlabs/apps/puppetserver
# to use. To use the default enter 'default'. (Does not affect PE.)
# @see https://puppet.com/docs/puppetserver/5.0/configuration.html#enabling-jruby-9k:
#
# @param java_temp_dir
#   The temporary directory to be used for periodic executables.
#
#   * This should not be ``/tmp``, ``/var/tmp``, or ``/dev/shm`` on SIMP
#     systems due to the default disabling of exec on those spaces.
#   * Preceeding directories will not be created.
#
# @param extra_java_args
#   An ``Array`` that will be joined and appended to the Java argument list.
#
#   * The sanity and syntax of this list will not be checked.
#
# @param service_stop_retries
#   The number of times to attempt to stop the puppetserver process before
#   failing.
#
# @param start_timeout
#   The number of seconds after which the service will be determined to have
#   failed to start.
#
# @param server_distribution
#   The Puppet distribution that is being managed.
#
# @param service
#   The ``puppetserver`` service name.
#
# @param user
#   The ``user`` that the ``puppetserver`` service will run as.
#
# @param group
#   The ``group`` that the ``puppetserver`` service will run as.
#
# @param mock
#   Do not apply this class, only mock it up
#
class pupmod::master::sysconfig (
  Stdlib::AbsolutePath           $install_dir          = $::pupmod::params::master_install_dir,
  Stdlib::AbsolutePath           $config               = $::pupmod::params::master_config['confdir'],
  Array[Stdlib::AbsolutePath]    $bootstrap_config     = $::pupmod::params::master_bootstrap_config,
  Stdlib::AbsolutePath           $java_bin             = '/usr/bin/java',
  Optional[Pupmod::Memory]       $java_start_memory    = undef,
  Pupmod::Memory                 $java_max_memory      = '50%',
  Optional[Stdlib::AbsolutePath] $java_temp_dir        = undef,
  String                         $jruby_jar            = 'jruby-9k.jar',
  Optional[Array[String]]        $extra_java_args      = undef,
  Integer                        $service_stop_retries = 60,
  Integer                        $start_timeout        = 120,
  Simplib::ServerDistribution    $server_distribution  = 'PC1',
  String                         $service              = $server_distribution ? { 'PE' => 'pe-puppetserver', default => 'puppetserver'},
  String                         $user                 = $facts['puppet_settings']['master']['user'],
  String                         $group                = $facts['puppet_settings']['master']['group'],
  Boolean                        $mock                 = false
) inherits pupmod {
  unless (mock == true) {
    if empty($java_temp_dir) {
      # puppet_settings.master.server_datadir is not always present, but its parent is
      $_java_temp_dir = "${dirname(fact('puppet_settings.master.server_datadir'))}/pserver_tmp"
    }
    else {
      $_java_temp_dir = $java_temp_dir
    }

    file { $_java_temp_dir:
      ensure => 'directory',
      owner  => $user,
      group  => $group,
      mode   => '0750'
    }



    if ($server_distribution == 'PE') {
      if (has_key($facts, 'pe_build')) {
        if (SemVer($facts['pe_build']) < SemVer('2016.4.0')) {
          pe_ini_subsetting { 'pupmod::master::sysconfig::javatempdir':
            path              => '/etc/sysconfig/pe-puppetserver',
            section           => '',
            setting           => 'JAVA_ARGS',
            subsetting        => '-Djava.io.tmpdir',
            quote_char        => '"',
            value             => "=${_java_temp_dir}",
            key_val_separator => '=',
            notify            => Service[$service],
          }
        }
      }
    }
    else {
      # Use alternate jruby file  only if file exists
      # in the installation directory defined in the puppetserver_jruby fact.
      if $jruby_jar != 'default' and $facts['puppetserver_jruby'] {
        $_jruby_jar = member($facts['puppetserver_jruby']['jarfiles'], $jruby_jar) ? {
          true  => "${facts['puppetserver_jruby']['dir']}/${jruby_jar}",
          false => 'default'
        }
      } else {
        $_jruby_jar = 'default'
      }

      file { "/etc/sysconfig/${service}":
        owner   => 'root',
        group   => $group,
        mode    => '0640',
        content => epp("${module_name}/etc/sysconfig/puppetserver"),
        notify  => Service[$service]
      }
    }
  }
}
