# This class provides the sysconfig settings for the ``puppetserver`` daemon.
#
# Each setting is edited in place in ``/etc/sysconfig/puppetserver`` only when
# its parameter is set; ``'absent'`` removes it. Each JVM option in
# ``JAVA_ARGS`` and ``JAVA_ARGS_CLI`` is managed separately, so options this
# class doesn't manage are left alone.
#
# @param install_dir
#   The installation directory for the ``puppetserver``, written as
#   ``INSTALL_DIR``.
#
# @param config
#   The configuration directory for the ``puppetserver``, written as
#   ``CONFIG``.
#
# @param bootstrap_config
#   The bootstrap configuration directories for the ``puppetserver``, written
#   as ``BOOTSTRAP_CONFIG``.
#
# @param java_bin
#   The path to the java executable that the Puppet server should use on the
#   system, written as ``JAVA_BIN``.
#
# @param java_start_memory
#   The amount of memory to allocate on service startup, written as ``-Xms``.
#
#   * When unset, ``-Xms`` follows ``java_max_memory`` whenever that is set,
#     because the JVM refuses to start with ``-Xms`` above ``-Xmx``.
#
# @param java_max_memory
#   The maximum amount of memory to allocate within the system, written as
#   ``-Xmx``.
#
#   * A percentage is a share of the system's memory.
#   * ``'auto'`` computes it from ``pupmod::master::max_active_instances``
#     with ``pupmod::java_max_memory()``.
#
# @param jruby_jar
#   The name of the jar file located in /opt/puppetlabs/apps/puppetserver
#   to use, written as ``JRUBY_JAR``. ``'default'``, or a jar that isn't
#   installed, removes ``JRUBY_JAR`` so that puppetserver uses its default.
#   (Does not affect PE.)
#
# @param java_temp_dir
#   The temporary directory to be used for periodic executables, written as
#   ``-Djava.io.tmpdir``. The directory is created.
#
#   * This should not be ``/tmp``, ``/var/tmp``, or ``/dev/shm`` on SIMP
#     systems due to the default disabling of exec on those spaces.
#   * Preceeding directories will not be created.
#
# @param extra_java_args
#   Java options to add to ``JAVA_ARGS`` and ``JAVA_ARGS_CLI``.
#
#   * The sanity and syntax of this list will not be checked.
#
# @param use_code_cache_flushing
#   Enable code cache flushing to alleviate memory strain on the server:
#   ``true`` writes ``-XX:+UseCodeCacheFlushing`` and ``false`` writes
#   ``-XX:-UseCodeCacheFlushing``.
#
# @param reserved_code_cache
#   The MB to be used for JRuby options of ReservedCodeCache, written as
#   ``-XX:ReservedCodeCacheSize``. ``0`` removes the option.
#
#   * ``'auto'`` computes it from the system's memory with
#     ``pupmod::reserved_code_cache()``.
#
# @param java_redhat_fips
#   Written as ``-Dcom.redhat.fips``. ``false`` stops the Red Hat JVM from
#   applying the system's FIPS policy to puppetserver.
#
# @param service_stop_retries
#   The number of times to attempt to stop the puppetserver process before
#   failing, written as ``SERVICE_STOP_RETRIES``.
#
# @param start_timeout
#   The number of seconds after which the service will be determined to have
#   failed to start, written as ``START_TIMEOUT``.
#
# @param server_distribution
#   The Puppet distribution that is being managed.
#
# @param user
#   The owner of ``java_temp_dir``.
#
# @param group
#   The group of ``java_temp_dir``.
#
# @param mock
#   Do not apply this class, only mock it up
#
class pupmod::master::sysconfig (
  Optional[Variant[Stdlib::AbsolutePath, Enum['absent']]]                $install_dir             = undef,
  Optional[Variant[Stdlib::AbsolutePath, Enum['absent']]]                $config                  = undef,
  Optional[Variant[Array[Stdlib::AbsolutePath, 1], Enum['absent']]]      $bootstrap_config        = undef,
  Optional[Variant[Stdlib::AbsolutePath, Enum['absent']]]                $java_bin                = undef,
  Optional[Variant[Pupmod::Memory, Enum['absent']]]                      $java_start_memory       = undef,
  Optional[Variant[Pupmod::Memory, Enum['auto', 'absent']]]              $java_max_memory         = undef,
  Optional[Variant[Stdlib::AbsolutePath, Enum['absent']]]                $java_temp_dir           = undef,
  Optional[String[1]]                                                    $jruby_jar               = undef,
  Optional[Array[String[1]]]                                             $extra_java_args         = undef,
  Optional[Boolean]                                                      $use_code_cache_flushing = undef,
  Optional[Variant[Integer[0], Enum['auto', 'absent']]]                  $reserved_code_cache     = undef,
  Optional[Variant[Boolean, Enum['absent']]]                             $java_redhat_fips        = undef,
  Optional[Variant[Integer, Enum['absent']]]                             $service_stop_retries    = undef,
  Optional[Variant[Integer, Enum['absent']]]                             $start_timeout           = undef,
  Enum['openvox-server', 'PC1', 'PE']                                    $server_distribution     = pupmod::server_distribution(),
  String                                                                 $user                    = pick($facts.dig('puppet_settings','server','user'),$facts.dig('puppet_settings','master','user')),
  String                                                                 $group                   = pick($facts.dig('puppet_settings','server','group'),$facts.dig('puppet_settings','master','group')),
  Boolean                                                                $mock                    = false
) inherits pupmod {
  include 'pupmod::master::service'

  unless $mock {
    $_pe = ($server_distribution == 'PE') or defined(Class['puppet_enterprise::profile::master'])

    if $java_max_memory == 'auto' {
      if $_pe {
        # If this is PE use the PE default for this run since the variable won't exist
        $_tuning_max_active_instances = max(($facts['processors']['count'] - 1), 1)
      } else {
        $_tuning_max_active_instances = $pupmod::master::max_active_instances ? {
          Integer => $pupmod::master::max_active_instances,
          default => pupmod::max_active_instances($pupmod::master::server_type),
        }
      }

      $_java_max_memory = pupmod::java_max_memory($_tuning_max_active_instances)
    }
    else {
      $_java_max_memory = $java_max_memory
    }

    # A percentage is a share of the system memory
    if ($_java_max_memory =~ String) and ($_java_max_memory[-1] == '%') {
      $_java_mem_mb = Integer(($facts['memory']['system']['total_bytes'] / 1048576) * (Numeric($_java_max_memory[0,-2])/100.00))
      $_xmx = "${_java_mem_mb}m"
    }
    else {
      $_xmx = $_java_max_memory
    }

    # The JVM won't start with -Xms above -Xmx, so -Xms follows -Xmx unless
    # it is set
    $_xms = $java_start_memory.lest || { $_xmx }

    if $java_temp_dir =~ NotUndef and $java_temp_dir != 'absent' {
      file { $java_temp_dir:
        ensure => 'directory',
        owner  => $user,
        group  => $group,
        mode   => '0750',
      }
    }

    if $_pe {
      if ($java_temp_dir =~ NotUndef) and ('pe_build' in $facts.keys) {
        if (SemVer($facts['pe_build']) < SemVer('2016.4.0')) {
          ['JAVA_ARGS', 'JAVA_ARGS_CLI'].each |String $setting| {
            pe_ini_subsetting { "pupmod::master::sysconfig::javatempdir for ${setting}":
              ensure            => ($java_temp_dir == 'absent').bool2str('absent', 'present'),
              path              => '/etc/sysconfig/pe-puppetserver',
              section           => '',
              setting           => $setting,
              subsetting        => '-Djava.io.tmpdir',
              quote_char        => '"',
              value             => "=${java_temp_dir}",
              key_val_separator => '=',
              notify            => Class['pupmod::master::service'],
            }
          }
        }
      }
    }
    else {
      $_sysconfig = "/etc/sysconfig/${pupmod::master::service::service_name}"
      $_resource_defaults = {
        'path'              => $_sysconfig,
        'section'           => '',
        'key_val_separator' => '=',
        'require'           => Class['pupmod::master::install'],
        'notify'            => Class['pupmod::master::service'],
      }

      # Use the alternate jruby file only if it exists in the installation
      # directory defined in the puppetserver_jruby fact
      if $jruby_jar =~ Undef {
        $_jruby_jar = undef
      }
      elsif $jruby_jar == 'default' {
        $_jruby_jar = 'absent'
      }
      elsif member(pick($facts.dig('puppetserver_jruby', 'jarfiles'), []), $jruby_jar) {
        $_jruby_jar = "${facts['puppetserver_jruby']['dir']}/${jruby_jar}"
      }
      else {
        $_jruby_jar = 'absent'
      }

      $_bootstrap_config = $bootstrap_config ? {
        Array   => join($bootstrap_config, ','),
        default => $bootstrap_config,
      }

      $_settings = {
        'JAVA_BIN'             => $java_bin,
        'JRUBY_JAR'            => $_jruby_jar,
        'INSTALL_DIR'          => $install_dir,
        'CONFIG'               => $config,
        'BOOTSTRAP_CONFIG'     => $_bootstrap_config,
        'SERVICE_STOP_RETRIES' => $service_stop_retries,
        'START_TIMEOUT'        => $start_timeout,
      }

      $_settings.each |String[1] $setting, $value| {
        if $value =~ NotUndef {
          $_ensure = $value ? {
            'absent' => 'absent',
            default  => 'present',
          }

          $_value = $value ? {
            Integer => $value,
            default => "\"${value}\"",
          }

          ini_setting { "pupmod::master::sysconfig ${setting}":
            ensure  => $_ensure,
            setting => $setting,
            value   => $_value,
            *       => $_resource_defaults,
          }
        }
      }

      $_reserved_code_cache = $reserved_code_cache ? {
        'auto'  => pupmod::reserved_code_cache(),
        default => $reserved_code_cache,
      }

      $_code_cache_flushing = $use_code_cache_flushing ? {
        true    => { '-XX:+UseCodeCacheFlushing' => '', '-XX:-UseCodeCacheFlushing' => 'absent' },
        false   => { '-XX:-UseCodeCacheFlushing' => '', '-XX:+UseCodeCacheFlushing' => 'absent' },
        default => {},
      }

      # JVM options of the form <option>=<value>
      $_assigned_java_args = {
        '-Dcom.redhat.fips'         => $java_redhat_fips,
        '-Djava.io.tmpdir'          => $java_temp_dir,
        '-XX:ReservedCodeCacheSize' => $_reserved_code_cache ? {
          Integer => ($_reserved_code_cache == 0).bool2str('absent', "${_reserved_code_cache}m"),
          default => $_reserved_code_cache,
        },
      }.filter |$option, $value| { $value =~ NotUndef }.reduce({}) |$memo, $option| {
        $memo + { $option[0] => ($option[1] == 'absent').bool2str('absent', "=${option[1]}") }
      }

      $_extra_java_args = pick($extra_java_args, []).reduce({}) |$memo, $arg| { $memo + { $arg => '' } }

      # JVM option => value appended to it
      $_java_args = {
        '-Xms' => $_xms,
        '-Xmx' => $_xmx,
      } + $_assigned_java_args + $_code_cache_flushing + $_extra_java_args

      $_java_args_settings = ['JAVA_ARGS', 'JAVA_ARGS_CLI']

      $_java_args_settings.each |String $setting| {
        $_java_args.each |String[1] $subsetting, $value| {
          if $value =~ NotUndef {
            $_ensure = $value ? {
              'absent' => 'absent',
              default  => 'present',
            }

            ini_subsetting { "pupmod::master::sysconfig ${setting} ${subsetting}":
              ensure     => $_ensure,
              setting    => $setting,
              subsetting => $subsetting,
              value      => $value,
              quote_char => '"',
              *          => $_resource_defaults,
            }
          }
        }
      }
    }
  }
}
