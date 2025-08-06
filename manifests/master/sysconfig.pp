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
# @param use_code_cache_flushing
#   Enable code cache flushing to alleviate memory strain on the server
#
# @param reserved_code_cache
#   An ``Integer`` of the MB to be used for JRuby options of ReservedCodeCache
#
#   * By default, this will auto-populate based on function
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
  Stdlib::AbsolutePath                 $install_dir,
  Stdlib::AbsolutePath                 $config,
  Array[Stdlib::AbsolutePath]          $bootstrap_config,
  Stdlib::AbsolutePath                 $java_bin                = '/usr/bin/java',
  Optional[Pupmod::Memory]             $java_start_memory       = undef,
  Optional[Pupmod::Memory]             $java_max_memory         = undef,
  Optional[Stdlib::AbsolutePath]       $java_temp_dir           = undef,
  String                               $jruby_jar               = 'jruby-9k.jar',
  Optional[Array[String]]              $extra_java_args         = undef,
  Boolean                              $use_code_cache_flushing = true,
  Integer[0]                           $reserved_code_cache     = pupmod::reserved_code_cache(),
  Integer                              $service_stop_retries    = 60,
  Integer                              $start_timeout           = 120,
  Enum['openvox-server', 'PC1', 'PE']  $server_distribution     = pupmod::server_distribution(),
  String                               $user                    = pick($facts.dig('puppet_settings','server','user'),$facts.dig('puppet_settings','master','user')),
  String                               $group                   = pick($facts.dig('puppet_settings','server','group'),$facts.dig('puppet_settings','master','group')),
  Boolean                              $mock                    = false
) inherits pupmod {
  include 'pupmod::master::service'

  unless $mock {
    if ($server_distribution == 'PE') or defined(Class['puppet_enterprise::profile::master']) {
      # If this is PE use the PE default for this run since the variable won't exist
      $_tuning_max_active_instances = max(($facts['processors']['count'] - 1), 1)
    } else {
      $_tuning_max_active_instances = $pupmod::master::max_active_instances
    }
    $_java_max_memory = $java_max_memory.lest || { pupmod::java_max_memory($_tuning_max_active_instances) }

    # In Puppet 6.19 the section "master was renamed to "server" in Puppet.settings.
    # pick is used here to determine correct value for backwards compatability
    $_server_datadir = pick($facts.dig('puppet_settings','server','server_datadir'),$facts.dig('puppet_settings','master','server_datadir'))

    $_java_temp_dir = $java_temp_dir.empty ? {
      # puppet_settings.master.server_datadir is not always present, but its parent is
      true    => "${_server_datadir.dirname}/pserver_tmp",
      default => $java_temp_dir,
    }

    file { $_java_temp_dir:
      ensure => 'directory',
      owner  => $user,
      group  => $group,
      mode   => '0750',
    }

    if ($server_distribution == 'PE') {
      if 'pe_build' in $facts.keys {
        if (SemVer($facts['pe_build']) < SemVer('2016.4.0')) {
          ['JAVA_ARGS', 'JAVA_ARGS_CLI'].each |String $setting| {
            pe_ini_subsetting { "pupmod::master::sysconfig::javatempdir for ${setting}":
              path              => '/etc/sysconfig/pe-puppetserver',
              section           => '',
              setting           => $setting,
              subsetting        => '-Djava.io.tmpdir',
              quote_char        => '"',
              value             => "=${_java_temp_dir}",
              key_val_separator => '=',
              notify            => Class['pupmod::master::service'],
            }
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

      file { "/etc/sysconfig/${pupmod::master::service::service_name}":
        owner   => 'root',
        group   => $group,
        mode    => '0640',
        content => epp("${module_name}/etc/sysconfig/puppetserver"),
        notify  => Class['pupmod::master::service'],
      }
    }
  }
}
