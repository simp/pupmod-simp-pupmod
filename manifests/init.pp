# @summary Manage the Puppet agent
#
# A bare `include pupmod` installs the agent package and does nothing else.
# Every other behavior is turned on by setting the parameter that controls it.
#
# Settings follow a three-state contract:
#
# * `undef` (the default) leaves the setting alone
# * a value writes it, replacing any earlier value
# * `'absent'` removes it (`false` for the Booleans that toggle a resource)
#
# Unless noted otherwise, `puppet.conf` settings are written to the `[main]`
# section.
#
# The `simp:defaults` compliance profile restores the behavior of `pupmod`
# before 13.0.0. See the README for details.
#
# @param ca_port
#   The port where the remote CA should be contacted, written as `ca_port`.
#
#   Defaults to `simp_options::puppet::ca_port` when that is set.
#
# @param ca_server
#   The puppet CA from which to obtain your system certificates, written as
#   `ca_server`.
#
#   Defaults to `simp_options::puppet::ca` when that is set.
#
# @param puppet_server
#   One or more puppet servers from which to retrieve your configuration.
#
#   * A single host is written as `server`, and `server_list` is removed.
#   * An Array is written as `server_list`, and `server` is removed.
#   * `'absent'` removes both.
#
#   Defaults to `simp_options::puppet::server` when that is set.
#
# @param server_distribution
#   The server distribution used. This changes the configuration based on whether
#   we are using PC1 or PE
#
# @param certname
#   The puppet certificate CN name of the system, written as `certname`.
#
# @param classfile
#   The path to the puppet class file, written as `classfile`.
#
#   Must be an absolute path or begin with a puppet setting such as `$vardir`.
#
# @param confdir
#   The path to the puppet configuration directory, which holds `puppet.conf`.
#
#   This is where the module edits `puppet.conf`. It is not written to
#   `puppet.conf`; use `main_settings` for that.
#
# @param daemonize
#   Whether or not to daemonize the Puppet agent.
#
#   * `true` runs the `puppet` service, writes `daemonize = true` to the
#     `[agent]` section, and removes the systemd timer.
#   * `false` stops and disables the `puppet` service, writes
#     `daemonize = false`, and schedules agent runs with
#     `pupmod::agent::cron`.
#   * `undef` leaves the service, the timer and the setting alone.
#
# @param digest_algorithm
#   The hash Digest to use for file operations on the system, written as
#   `digest_algorithm`.
#
# @param enable_puppet_master
#   Whether or not to make the system a puppetmaster.
#
# @param environmentpath
#   The path to the directory holding the puppet environments.
#
#   This is the default for `pupmod::master::environmentpath` and is not
#   written to `puppet.conf` by this class.
#
# @param listen
#   Unused.
#
# @param logdir
#   The path to the puppet log directory.
#
#   Log purging (`purge_logs`) works relative to its parent directory. It is
#   not written to `puppet.conf`; use `main_settings` for that.
#
# @param main_settings
#   Additional settings for the `[main]` section of `puppet.conf`, as
#   `setting => value`. A value of `'absent'` removes the setting.
#
#   Merged with `deep`, so each Hiera layer can add, change or remove single
#   settings. A setting that one of this class's named parameters also
#   writes (for example `splay`) is taken from the named parameter.
#
# @param purge_logs
#   Purge old logs from the system, using a systemd tmpfiles drop-in.
#
#   * `true` writes the drop-in.
#   * `false` removes it.
#   * `undef` leaves it alone.
#
# @param purge_logs_duration
#   The timeframe after which logs will be purged.
#
#   * Uses systemd tmpfiles age notation
#   * Only used when `purge_logs` is `true`
#
# @param purge_log_dirs
#   The directories under the parent of `$logdir` to be purged.
#
#   * Only used when `purge_logs` is `true`
#
# @param masterport
#   The port where the Puppet Master should be contacted, written as
#   `masterport`.
#
# @param report
#   Whether or not to send reports to the report server, written as `report`
#   to the `[agent]` section.
#
# @param rundir
#   The path to the puppet run status directory.
#
#   It is not written to `puppet.conf`; use `main_settings` for that.
#
# @param runinterval
#   The number of seconds between puppet runs, written as `runinterval`.
#
#   Has no effect on the client cron job.
#
# @param splay
#   Whether or not to splay the puppet runs, written as `splay`.
#
# @param splaylimit
#   The maximum time to delay before an agent's first run when `splay` is
#   enabled, written as `splaylimit`.
#
# @param srv_domain
#   The domain to search when using SRV records, written as `srv_domain`.
#
# @param ssldir
#   The path to the puppet ssl directory.
#
#   The puppetserver configuration refers to it. It is not written to
#   `puppet.conf`; use `main_settings` for that.
#
# @param syslogfacility
#   The Syslog facility to use when outputting messages from puppet, written
#   as `syslogfacility`.
#
# @param use_srv_records
#   Unused.
#
# @param haveged
#   If true, include haveged to assist with entropy generation.
#
# @param fips
#   Unused, and deprecated.
#
#   Before 13.0.0 this chose the CA key length on a puppet server. Set
#   `pupmod::master::keylength` instead.
#
# @param vardir
#   The directory where puppet will store all of its 'variable' data.
#
#   It is not written to `puppet.conf`; use `main_settings` for that.
#
# @param manage_facter_conf
#   Deprecated: the Facter configuration is managed whenever `facter_options`
#   is not empty. Setting this to `false` still turns that off.
#
# @param facter_conf_dir
#   Directory containing the Facter configuration file.
#
# @param facter_options
#   Hash of Facter configuration options, as `section => { key => value }`.
#
#   - Each primary key is a section in the Facter configuration file
#     (e.g., 'facts', 'global', 'cli')
#   - Each key in a section is written separately. A value of `'absent'`
#     removes that key.
#   - An empty section (`{}`) removes that section entirely.
#   - When this is empty (the default), the Facter configuration is left
#     alone.
#   - See https://puppet.com/docs/facter/latest/configuring_facter.html
#     for details on how to configure Facter.
#
# @param openvox_base_url
#   The base url for the openvox package repo
#
# @param openvox_release_url
#   The url for the openvox release package.
#
# @param openvox_rpm_path
#   The location of the openvox-server rpm to be installed
#   The openvox_release_url parameter will be ignored if this parameter is set.
#
# @param puppet_agent_sebool_package
#   The name of the package that provides the `puppetagent_manage_all_files`
#   SELinux boolean.
#
# @param manage_puppet_sebool_package
#   Whether the package named by `puppet_agent_sebool_package` must be
#   installed before `puppetagent_manage_all_files` can be set.
#
#   This describes the OS release and is set in module data.
#
# @param puppetagent_manage_all_files
#   The value of the `puppetagent_manage_all_files` SELinux boolean.
#
#   * `true` turns it on, installing `puppet_agent_sebool_package` first when
#     `manage_puppet_sebool_package` is `true`.
#   * `false` turns it off.
#   * `undef` leaves it alone.
#
#   Only applies when SELinux is enabled.
#
# @param manage_puppet_sebool
#   Deprecated: set `puppetagent_manage_all_files` instead.
#
#   `true` sets `puppetagent_manage_all_files` to `true` when that is unset.
#
# @param puppet_extra_opts
#   The value of `PUPPET_EXTRA_OPTS` in `/etc/sysconfig/puppet`. `'absent'`
#   removes the line.
#
# @param puppet_group
#   The group that owns Puppet's configuration directories and files.
#
#   When set, the group is created if it doesn't exist, and `$confdir` and
#   `puppet.conf` are owned by `root` and this group, with mode `0640` (except
#   on Puppet Enterprise, where the mode is left alone). On a puppet server,
#   `pupmod::master` manages the server's directories and configuration files
#   the same way.
#
# @param mock
#   If true, disable all code.
#
# @param firewall
#   Whether or not firewall rules should be created
#
# @param pe_classlist
#   Hash of Puppet Enterprise classes and the users, services and firewall
#   rules each one needs.
#
#   Empty by default, which turns off the Puppet Enterprise integration.
#
# @param agent_package
#   The name of the agent package to install.
#
# @param agent_package_install_options
#   An array of install options passed to the agent package provider.
#   See the Puppet `package` resource `install_options` attribute for the
#   provider-specific format.
#
# @param package_ensure
#   String used to specify 'latest', 'installed', or a specific version of the agent package
#
# @param set_environment
#   Set the environment on the system to the currently running environment
#
#   * This will automatically purge the `environment` setting from the `main`
#     section of the configuration to prevent issues from arising when running
#     various puppet tools. To prevent this from happening, you may set this to
#     `no_clean` and the entry will be preserved if present.
#
# @author https://github.com/simp/pupmod-simp-pupmod/graphs/contributors
#
class pupmod (
  Optional[Variant[Simplib::Host, Enum['$server', 'absent']]]              $ca_server                     = simplib::lookup('simp_options::puppet::ca', { 'default_value' => undef }),
  Optional[Variant[Simplib::Port, Enum['absent']]]                          $ca_port                       = simplib::lookup('simp_options::puppet::ca_port', { 'default_value' => undef }),
  Optional[Variant[Simplib::Host, Array[Simplib::Host, 1], Enum['absent']]] $puppet_server                 = simplib::lookup('simp_options::puppet::server', { 'default_value' => undef }),
  Enum['openvox-server', 'PC1', 'PE']                                       $server_distribution           = pupmod::server_distribution(false), # Can't self-reference in this lookup
  Optional[Variant[Simplib::Host, Enum['absent']]]                          $certname                      = undef,
  Optional[Variant[Pattern['^(\$(?!/)|/).+'], Enum['absent']]]              $classfile                     = undef,
  Optional[Boolean]                                                         $daemonize                     = undef,
  Optional[Enum['md5', 'sha256', 'absent']]                                 $digest_algorithm              = undef,
  Boolean                                                                   $enable_puppet_master          = false,
  Boolean                                                                   $listen                        = false,
  Hash[String[1], Scalar]                                                   $main_settings                 = {},
  Optional[Boolean]                                                         $purge_logs                    = undef,
  Pattern['\d+(h|m|w)']                                                     $purge_logs_duration           = '4w',
  Array[Stdlib::AbsolutePath]                                               $purge_log_dirs                = ['/puppet*'],
  Optional[Variant[Simplib::Port, Enum['absent']]]                          $masterport                    = undef,
  Optional[Variant[Boolean, Enum['absent']]]                                $report                        = undef,
  Optional[Variant[Integer[0], Enum['absent']]]                             $runinterval                   = undef,
  Optional[Variant[Boolean, Enum['absent']]]                                $splay                         = undef,
  Optional[Variant[Simplib::Host, Enum['absent']]]                          $srv_domain                    = undef,
  Optional[Variant[Simplib::Syslog::Facility, Enum['absent']]]              $syslogfacility                = undef,
  Boolean                                                                   $use_srv_records               = false,
  Boolean                                                                   $haveged                       = simplib::lookup('simp_options::haveged', { 'default_value' => false }),
  Boolean                                                                   $fips                          = simplib::lookup('simp_options::fips', { 'default_value' => false }),
  Boolean                                                                   $firewall                      = simplib::lookup('simp_options::firewall', { 'default_value' => false }),
  Hash                                                                      $pe_classlist                  = {},
  String[1]                                                                 $agent_package                 = 'openvox-agent',
  Optional[Array[Variant[String[1], Hash]]]                                 $agent_package_install_options = undef,
  String[1]                                                                 $package_ensure                = simplib::lookup('simp_options::package_ensure' , { 'default_value' => 'installed' }),
  Variant[Boolean, Enum['no_clean']]                                        $set_environment               = false,
  Optional[Boolean]                                                         $manage_facter_conf            = undef,
  Stdlib::Absolutepath                                                      $facter_conf_dir               = '/etc/puppetlabs/facter',
  Boolean                                                                   $mock                          = false,
  Stdlib::HTTPUrl                                                           $openvox_base_url              = 'https://yum.voxpupuli.org',
  Optional[Variant[Stdlib::Absolutepath, Stdlib::HTTPUrl]]                  $openvox_release_url           = undef,
  Optional[Variant[Stdlib::Absolutepath, Stdlib::HTTPUrl]]                  $openvox_rpm_path              = undef,
  String                                                                    $puppet_agent_sebool_package,  # module data
  Boolean                                                                   $manage_puppet_sebool_package, # module data
  Optional[Boolean]                                                         $puppetagent_manage_all_files  = undef,
  Optional[Boolean]                                                         $manage_puppet_sebool          = undef,
  Optional[Variant[String, Enum['absent']]]                                 $puppet_extra_opts             = undef,
  Optional[String[1]]                                                       $puppet_group                  = undef,
  Stdlib::AbsolutePath                                                      $confdir,
  Hash                                                                      $facter_options                = {},
  Stdlib::AbsolutePath                                                      $vardir,
  Stdlib::AbsolutePath                                                      $ssldir,
  Stdlib::AbsolutePath                                                      $rundir,
  Stdlib::AbsolutePath                                                      $logdir,
  Stdlib::AbsolutePath                                                      $environmentpath,
  Optional[Variant[Integer[1], Enum['absent']]]                             $splaylimit                    = undef,
) {
  unless $mock {
    simplib::assert_metadata($module_name)

    if $haveged {
      include 'haveged'
    }

    include pupmod::agent::install

    if $enable_puppet_master {
      include 'pupmod::master'
    }

    if $daemonize =~ NotUndef {
      if $daemonize {
        $_puppet_service_ensure = 'running'
        cron { 'puppetagent': ensure => 'absent' }

        # Stop and disable the timer before its unit file is removed so it is
        # unloaded and its timers.target.wants symlink is cleaned up
        systemd::timer { 'puppet_agent.timer':
          ensure => 'absent',
          active => false,
          enable => false,
        }

        # systemd::timer only manages the companion service unit when content
        # is passed, so its removal must be declared explicitly
        systemd::unit_file { 'puppet_agent.service':
          ensure  => 'absent',
          require => Systemd::Timer['puppet_agent.timer'],
        }

        file { ['/usr/local/bin/puppetagent_cron.sh', '/usr/local/bin/careful_puppet_service_shutdown.sh']:
          ensure  => 'absent',
          require => Systemd::Timer['puppet_agent.timer'],
        }
      }
      else {
        $_puppet_service_ensure = 'stopped'
        include 'pupmod::agent::cron'
      }

      service { 'puppet':
        ensure     => $_puppet_service_ensure,
        enable     => $daemonize,
        hasrestart => true,
        hasstatus  => true,
      }

      pupmod::conf { 'agent_daemonize':
        section => 'agent',
        confdir => $confdir,
        setting => 'daemonize',
        value   => $daemonize,
      }
    }

    # This takes some explaining. You may be asking yourself: Dear god? why?
    #
    # The short answer is, to make the UX for PE better, we need to make no
    # assumptions about the amount of configuration the user has done before
    # trying to lay SIMP on top of PE.
    #
    # Therefore, we have to inspect the catalog to see which PE
    # classes are included, and tailor our configuration
    # accordingly.
    #
    # To do this we have to use defined(). But this has an inherent
    # race condition if you use it in a normal class, as if this class
    # is evaluated before the class you are checking, you
    # will get an erroneous false result.
    #
    # The workaround is to take advantage of the fact that the puppet catalog
    # compiler takes multiple passes, a first pass for most classes to be
    # evaluated, and a second pass for resource collection statements. Basically
    # by creating a virtual defined type and realizing it immediately, we
    # 'throw' any puppet code in the defined type into the next pass of the
    # compiler.
    #
    # Disgusting? yes. Necessary? unfortunately. This will have to be
    # re-evaluated for every major PE release.

    @pupmod::pass_two { 'main':
      server_distribution => $server_distribution,
      confdir             => $confdir,
      firewall            => $firewall,
      pe_classlist        => $pe_classlist,
      puppet_group        => $puppet_group,
      pupmod_server       => $puppet_server,
      pupmod_ca_server    => $ca_server,
      pupmod_masterport   => $masterport,
      pupmod_ca_port      => $ca_port,
      pupmod_report       => $report,
    }
    Pupmod::Pass_two <| |>

    if $set_environment {
      unless ($set_environment == 'no_clean') {
        pupmod::conf { 'remove environment from main':
          ensure  => 'absent',
          section => 'main',
          confdir => $confdir,
          setting => 'environment',
          value   => null,
        }
      }

      unless simplib::in_bolt() {
        pupmod::conf { 'environment':
          confdir => $confdir,
          setting => 'environment',
          value   => $environment,
        }
      }
    }

    # The named parameters win over the same setting in $main_settings
    $_main_settings = $main_settings + {
      'splay'            => $splay,
      'splaylimit'       => $splaylimit,
      'syslogfacility'   => $syslogfacility,
      'srv_domain'       => $srv_domain,
      'certname'         => $certname,
      'classfile'        => $classfile,
      'runinterval'      => $runinterval,
      'digest_algorithm' => $digest_algorithm,
    }

    $_main_settings.each |String[1] $setting, Optional[Scalar] $value| {
      if $value =~ NotUndef {
        $_ensure = $value ? {
          'absent' => 'absent',
          default  => 'present',
        }

        pupmod::conf { $setting:
          ensure  => $_ensure,
          confdir => $confdir,
          setting => $setting,
          value   => $value,
        }
      }
    }

    if $puppet_extra_opts =~ NotUndef {
      $_extra_opts = $puppet_extra_opts ? {
        'absent' => { 'ensure' => 'absent', 'match_for_absence' => true },
        default  => { 'ensure' => 'present' },
      }

      file_line { 'pupmod PUPPET_EXTRA_OPTS':
        path    => '/etc/sysconfig/puppet',
        line    => "PUPPET_EXTRA_OPTS='${puppet_extra_opts}'",
        match   => '^\s*PUPPET_EXTRA_OPTS=',
        require => Class['pupmod::agent::install'],
        *       => $_extra_opts,
      }
    }

    if $manage_puppet_sebool =~ NotUndef {
      deprecation('pupmod::manage_puppet_sebool', 'pupmod::manage_puppet_sebool is deprecated. Set pupmod::puppetagent_manage_all_files instead.', false)
    }

    $_puppet_agent_sebool_value = $puppetagent_manage_all_files ? {
      undef   => $manage_puppet_sebool ? {
        true    => true,
        default => undef,
      },
      default => $puppetagent_manage_all_files,
    }

    $puppet_agent_sebool = 'puppetagent_manage_all_files'
    if ($_puppet_agent_sebool_value =~ NotUndef) and $facts['os']['selinux']['enabled'] and $facts['os']['selinux']['current_mode'] and ($facts['os']['selinux']['current_mode'] != 'disabled') {
      # The package only provides the boolean, so it is needed to turn it on
      if $_puppet_agent_sebool_value and $manage_puppet_sebool_package {
        package { $puppet_agent_sebool_package:
          ensure => 'installed',
        }

        exec { "Refresh semodules after installing ${puppet_agent_sebool_package}":
          command => '/usr/sbin/semodule --refresh',
          unless  => "/usr/sbin/getsebool ${puppet_agent_sebool}",
          require => Package[$puppet_agent_sebool_package],
          before  => Exec["Set ${puppet_agent_sebool} seboolean"],
        }
      }

      $_sebool_state = $_puppet_agent_sebool_value ? {
        true    => 'on',
        default => 'off',
      }

      # An `exec` is used here instead of `selboolean` so that a first-run
      # `--noop` does not fail: the `selboolean` provider errors out when it
      # probes a boolean that does not exist yet, whereas a failing `unless`
      # check simply reports the command as out of sync (SIMP #241).
      exec { "Set ${puppet_agent_sebool} seboolean":
        command => "/usr/sbin/setsebool -P ${puppet_agent_sebool} ${_sebool_state}",
        unless  => "/usr/sbin/getsebool ${puppet_agent_sebool} | /usr/bin/grep -q ' --> ${_sebool_state}'",
      }
    }

    if $manage_facter_conf =~ NotUndef {
      deprecation('pupmod::manage_facter_conf', 'pupmod::manage_facter_conf is deprecated. The Facter configuration is managed whenever pupmod::facter_options is not empty.', false)
    }

    if ($manage_facter_conf != false) and !empty($facter_options) {
      include 'pupmod::facter::conf'
    }

    if $purge_logs =~ NotUndef {
      if $purge_logs and !empty($purge_log_dirs) {
        $_purge_logdir = dirname($logdir)

        if empty($_purge_logdir) or ($_purge_logdir == '/') {
          fail("Refusing to purge top-level directories. Please ensure that ${module_name}::logdir is set to something sensible.")
        }

        $_purge_logs_content = $purge_log_dirs.map |$x| { "e ${_purge_logdir}${x} - - - ${purge_logs_duration}" }

        systemd::tmpfile { 'puppet_purge_puppet_service_logs.conf':
          content => join($_purge_logs_content, "\n"),
        }
      }
      else {
        systemd::tmpfile { 'puppet_purge_puppet_service_logs.conf': ensure => 'absent' }
      }
    }
  }
}
