# @summary Provides configuration for a puppet master.
#
# A bare `include pupmod::master` installs the server package and does
# nothing else. Every other behavior is turned on by setting the parameter
# that controls it, here or in the `pupmod::master::*` classes.
#
# Settings follow a three-state contract:
#
# * `undef` (the default) leaves the setting alone
# * a value writes it, replacing any earlier value
# * `'absent'` removes it
#
# The puppetserver configuration files are edited in place, one setting at a
# time, so settings this module doesn't manage are left as the package or an
# administrator wrote them.
#
# The `simp:defaults` compliance profile restores the behavior of
# `pupmod::master` before 13.0.0. See the README for details.
#
# @see https://puppet.com/docs/puppetserver/latest/config_file_puppetserver.html
#
# @param bind_address
#   The IP address to which the Puppet Master process should bind, written as
#   `ssl-host` of the main server in `webserver.conf`
#
# @param ca_allow_auth_extensions
#   Whether the CA may sign certificates with authorization extensions,
#   written as `certificate-authority.allow-authorization-extensions` in
#   `ca.conf`
#
# @param ca_allow_alt_names
#   Whether the CA may sign certificates with subject alternative names,
#   written as `certificate-authority.allow-subject-alt-names` in `ca.conf`
#
# @param ca_bind_address
#   The IP address to which the Puppet CA process should bind, written as
#   `ssl-host` of the `ca` server in `webserver.conf`
#
#   * Only used when the CA has its own port (see `ca_port`). The CA listens
#     on the main server's address when this is not set.
#
# @param auditd
#   If true, adds an audit record to watch sensitive Puppet directories for
#   changes by any user that is not the puppet user.
#
# @param ca_port
#   The port upon which the CA should listen, written as `ca_port` in the
#   `[server]` section of `puppet.conf`.
#
#   When it differs from the main server's port, the CA runs as its own
#   server: `webserver.conf` gets a `ca` server listening on this port (and
#   is converted to named servers if it isn't already), and the CA route in
#   `web-routes.conf` points to it. When it is the same port, the `ca`
#   server is removed.
#
#   Defaults to `simp_options::puppet::ca_port` when that is set.
#
# @param trusted_nets
#   An array of networks from which to allow access to the master.
#
# @param server_distribution
#   *Deprecated*: The version of the server that is being managed.
#
#   * PC1 covers everything after Puppet 3
#
# @param server_type
#   The type of Puppet server this is. Can be 'monolithic', 'primary', or 'compile'
#   as defined in https://puppet.com/docs/puppetserver/latest/scaling_puppet_server.html
#
#   Used to compute `max_active_instances` and the JVM heap size when those
#   are set to `'auto'`.
#
# @param ca_ttl
#   This is the length after which the CA certificate will no longer be
#   valid, written as `ca_ttl` in the `[server]` section of `puppet.conf`.
#
# @param daemonize
#   Whether or not to run the server as a daemon, written as `daemonize` in
#   the `[server]` section of `puppet.conf`.
#
# @param enable_ca
#   Whether or not the system should act as a CA.
#
#   * `true` enables the CA service in `services.d/ca.cfg`
#   * `false` enables the disabled CA service instead, and removes the `ca`
#     server from `webserver.conf`
#
# @param enable_master
#   Whether or not the system should act as a Puppet Master.
#
#   * `false` removes the main (`base`) server from a `webserver.conf` that
#     uses named servers, leaving only the CA. Only meaningful when the CA has
#     its own port.
#
# @param environmentpath
#   The location of all directory environments, written as
#   `environmentpath` in the `[server]` section of `puppet.conf`.
#
# @param freeze_main
#   Whether or not code is allowed outside of site.pp or a module, written as
#   `freeze_main` in `puppet.conf`.
#
# @param keylength
#   The bit length of keys the CA generates, written as `keylength` in the
#   `[server]` section of `puppet.conf`.
#
# @param masterport
#   The port upon which the Puppet master process will listen, written as
#   `masterport` in the `[server]` section of `puppet.conf` and as `ssl-port`
#   of the main server in `webserver.conf`.
#
#   `'absent'` removes the `puppet.conf` setting only; the main server keeps
#   its `ssl-port`.
#
# @param puppet_confdir
#   The Puppet client configuration directory, which holds `puppet.conf`.
#
# @param confdir
#   The puppetserver configuration directory (`conf.d`).
#
#   The `puppetserver_webserver` fact only reads the default
#   `/etc/puppetlabs/puppetserver/conf.d`. With another directory, the module
#   assumes a single-server `webserver.conf` until it converts the file to
#   named servers itself.
#
# @param codedir
#   The directory holding the Puppet configuration codebase.
#
# @param vardir
#   The Puppet server 'var' directory
#
# @param rundir
#   The Puppet server runtime directory
#
# @param logdir
#   The log directory for the Puppet server
#
# @param ssldir
#   The SSL configuration directory for the Puppet server
#
# @param server_conf_dir
#   Written as `jruby-puppet.server-conf-dir` in `puppetserver.conf`,
#   replacing the deprecated `master-conf-dir`.
#
# @param server_code_dir
#   Written as `jruby-puppet.server-code-dir` in `puppetserver.conf`,
#   replacing the deprecated `master-code-dir`.
#
# @param server_var_dir
#   Written as `jruby-puppet.server-var-dir` in `puppetserver.conf`,
#   replacing the deprecated `master-var-dir`.
#
# @param server_run_dir
#   Written as `jruby-puppet.server-run-dir` in `puppetserver.conf`,
#   replacing the deprecated `master-run-dir`.
#
# @param server_log_dir
#   Written as `jruby-puppet.server-log-dir` in `puppetserver.conf`,
#   replacing the deprecated `master-log-dir`.
#
# @param use_legacy_auth_conf
#   Enable processing of the legacy Puppetserver auth.conf, written as
#   `jruby-puppet.use-legacy-auth-conf`.
#
#   * This is **NOT** recommended and may cause a SIMP installation to
#     malfunction.
#
# @param max_queued_requests
#   The number of requests that may be queued against the server prior to being
#   rejected, written as `jruby-puppet.max-queued-requests`.
#
# @param max_retry_delay
#   The maximum time that a client will wait prior to giving up on the server
#   response, written as `jruby-puppet.max-retry-delay`.
#
# @param firewall
#   If enabled, will use the SIMP iptables classes to manipulate IPTables.
#
#   The main server's port is `masterport`, or `8140` when that is not set.
#   The CA's port is opened when `ca_port` is set.
#
# @param ca_status_whitelist
#   An array of certificate short names which will be allowed to query the CA end
#   point of the Puppet Server, written as
#   `certificate-authority.certificate-status.client-whitelist` together with
#   `authorization-required: true` in `ca.conf`
#
# @param ruby_load_path
#   The path to the system Ruby installation to use for the Puppet Server,
#   written as `os-settings.ruby-load-path` in `os-settings.conf`.
#
# @param max_active_instances
#   The maximum number of active JRuby instances to be run by the Puppet
#   Server, written as `jruby-puppet.max-active-instances`.
#
#   `'auto'` computes it from the system's processors and memory with
#   `pupmod::max_active_instances()`.
#
# @param max_requests_per_instance
#   The number of requests a given JRuby instance will process prior to being
#   stopped, written as `jruby-puppet.max-requests-per-instance`.
#
# @param borrow_timeout
#   The timeout, in milliseconds, when attempting to borrow an instance from
#   the JRuby pool, written as `jruby-puppet.borrow-timeout`.
#
# @param environment_class_cache_enabled
#   Maintain a cache in conjucntion with the use of the ``environment_classes``
#   API, written as `jruby-puppet.environment-class-cache-enabled`.
#
# @param compat_version
#   Unused: it only applied to ``puppetserver`` < 5.0.
#
# @param compile_mode
#   Set the JRuby ``CompileMode``, written as `jruby-puppet.compile-mode`.
#
# @param ssl_protocols
#   The protocols that are allowed for communication with the Puppet Server,
#   written as `http-client.ssl-protocols` in `puppetserver.conf` and as
#   `ssl-protocols` of each server in `webserver.conf`.
#
# @param ssl_cipher_suites
#   The allowed SSL Cipher Suites to be used by the Puppet Server, written as
#   `http-client.cipher-suites` in `puppetserver.conf` and as `cipher-suites`
#   of each server in `webserver.conf`. The allowed list is Java version
#   dependent and you will need to check the system Java documentation for
#   details.
#
# @param enable_profiler
#   Whether or not to enable the Puppet Server profiler to allow for code
#   metrics gathering, written as `profiler.enabled`.
#
# @param profiling_mode
#   The JRuby profiling mode to use when profiling the server, written as
#   `jruby-puppet.profiling-mode`.
#
# @param profiler_output_file
#   The file to use when outputting server profiling information, written as
#   `jruby-puppet.profiler-output-file`.
#
# @param admin_api_whitelist
#   A list of X.509 certificate names that should be allowed to access the
#   Puppet Server's administrative API, written as
#   `puppet-admin.client-whitelist`.
#
# @param admin_api_mountpoint
#   The endpoint for the Puppet Servers adminstrative API, written to
#   `web-routes.conf`. Changing this may break external utilities.
#
#   puppetserver needs this route, so it cannot be removed: `'absent'` fails
#   the catalog.
#
# @param log_to_file
#   Whether puppetserver logs to its log file: `true` adds the `F1` appender
#   to the root logger in `logback.xml`, `false` removes it.
#
# @param strict_hostname_checking
#   Whether to only search for the complete hostname as it is in the
#   certificate when searching for node information in teh catalogs or to match
#   dot delimited segments of the cert's certname and the hostname, fqdn,
#   and/or domain facts. Written as `strict_hostname_checking` in
#   `puppet.conf`.
#
#   * Do NOT set to `false` unless you have read the details of CVE-2020-7942
#
# @param cve_2020_7942_warning
#   Whether to warn about CVE-2020-7942 when the issue is detected.
#
# @param syslog
#   Whether puppetserver logs to the local system logger over UDP port 514:
#   `true` adds a `SYSLOG` appender to `logback.xml` and to its root logger,
#   `false` removes it from the root logger.
#
#   Defaults to `simp_options::syslog` when that is set.
#
# @param syslog_facility
#   The syslog facility of the `SYSLOG` appender. Only used when `syslog` is
#   `true`.
#
# @param syslog_message_format
#   The Logback compatible syslog message format of the `SYSLOG` appender.
#   For more information, see the Logback documentation for 'SuffixPattern'.
#   Only used when `syslog` is `true`.
#
# @param log_level
#   The level of the root logger and of the `org.eclipse.jetty` logger in
#   `logback.xml`. Be aware that anything below 'WARN' will provide a
#   massive amount of logs at each puppet run.
#
# @param autosign_hosts
#   Deprecated: use `autosign_entries`.
#
#   An array of hosts or host globs to add to the master's ``autosign.conf``
#   file. Each entry is added with `pupmod::master::autosign`.
#
# @param autosign_entries
#   Hosts or host globs to manage in the master's `autosign.conf`, each
#   mapped to its options. `{}` adds the entry.
#
#   Merged with `deep`, so a Hiera layer can remove one entry with
#   `{ ensure => absent }`.
#
# @option autosign_entries [Enum['present', 'absent']] :ensure
#   `absent` removes the entry. Defaults to `present`.
#
# @param package_ensure
#   String used to specify either 'latest', 'installed', or a specific version
#   of the puppetserver package
#
# @param enable_analytics
#   Enable the built-in analytics, and upgrade check, on the puppetserver,
#   written as `product.check-for-updates` in `product.conf`.
#
# @param server_webserver_options
#   Additional settings for the main server in `webserver.conf`, as
#   `key => value`. A value of `'absent'` removes the key.
#
#   Values are written as HOCON values of their own type; puppetserver
#   converts strings such as `'true'` and `'8140'` to the type it expects.
#   See
#   https://github.com/puppetlabs/trapperkeeper-webserver-jetty9/blob/master/doc/jetty-config.md
#
# @param ca_webserver_options
#   Additional settings for the `ca` server in `webserver.conf`, as
#   `key => value`. A value of `'absent'` removes the key.
#
#   Only used when the CA has its own port (see `ca_port`).
#
# @param extra_webserver_sections
#   Additional named servers in `webserver.conf`, as
#   `name => { key => value }`. Each key is written separately. A value of
#   `'absent'` removes the key.
#
#   Section Hash Example:
#
#   ```ruby
#   {
#     'section1_name' => {
#       'ssl-port' => 1234
#     },
#     'section2_name' => {
#       'ssl-port' => 2345
#     }
#   }
#   ```
#
#   Named servers only work in a `webserver.conf` that uses named servers.
#
# @param mock
#   DO NOT USE. needed for rspec testing
#
# @author https://github.com/simp/pupmod-simp-pupmod/graphs/contributors
#
class pupmod::master (
  Optional[Variant[Simplib::IP, Enum['absent']]]                              $bind_address                    = undef,
  Optional[Boolean]                                                           $ca_allow_auth_extensions        = undef,
  Optional[Boolean]                                                           $ca_allow_alt_names              = undef,
  Optional[Variant[Simplib::IP, Enum['absent']]]                              $ca_bind_address                 = undef,
  Boolean                                                                     $auditd                          = simplib::lookup('simp_options::auditd', { 'default_value' => false }),
  Optional[Variant[Simplib::Port, Enum['absent']]]                            $ca_port                         = simplib::lookup('simp_options::puppet::ca_port', { 'default_value' => undef }),
  Simplib::NetList                                                            $trusted_nets                    = simplib::lookup('simp_options::trusted_nets', { 'default_value' => ['127.0.0.1','::1'] }),
  String                                                                      $server_distribution             = pupmod::server_distribution(),
  Enum['monolithic', 'primary', 'compile']                                    $server_type                     = 'monolithic',
  Optional[Variant[Pupmod::CaTTL, Enum['absent']]]                            $ca_ttl                          = undef,
  Optional[Variant[Boolean, Enum['absent']]]                                  $daemonize                       = undef,
  Optional[Boolean]                                                           $enable_ca                       = undef,
  Optional[Boolean]                                                           $enable_master                   = undef,
  Optional[Variant[Stdlib::AbsolutePath, Enum['absent']]]                     $environmentpath                 = undef,
  Optional[Variant[Boolean, Enum['absent']]]                                  $freeze_main                     = undef,
  Optional[Variant[Integer[1024], Enum['absent']]]                            $keylength                       = undef,
  Optional[Variant[Simplib::Port, Enum['absent']]]                            $masterport                      = undef,
  Stdlib::AbsolutePath                                                        $puppet_confdir                  = $pupmod::confdir,
  Stdlib::AbsolutePath                                                        $confdir,
  Stdlib::AbsolutePath                                                        $codedir,
  Stdlib::AbsolutePath                                                        $vardir,
  Stdlib::AbsolutePath                                                        $rundir,
  Stdlib::AbsolutePath                                                        $logdir,
  Stdlib::AbsolutePath                                                        $ssldir,
  Optional[Variant[Stdlib::AbsolutePath, Enum['absent']]]                     $server_conf_dir                 = undef,
  Optional[Variant[Stdlib::AbsolutePath, Enum['absent']]]                     $server_code_dir                 = undef,
  Optional[Variant[Stdlib::AbsolutePath, Enum['absent']]]                     $server_var_dir                  = undef,
  Optional[Variant[Stdlib::AbsolutePath, Enum['absent']]]                     $server_run_dir                  = undef,
  Optional[Variant[Stdlib::AbsolutePath, Enum['absent']]]                     $server_log_dir                  = undef,
  Optional[Boolean]                                                           $use_legacy_auth_conf            = undef,
  Optional[Variant[Integer[0], Enum['absent']]]                               $max_queued_requests             = undef,
  Optional[Variant[Integer[1], Enum['absent']]]                              $max_retry_delay                 = undef,
  Boolean                                                                     $firewall                        = simplib::lookup('simp_options::firewall', { 'default_value' => false }),
  Optional[Variant[Array[Simplib::Host], Enum['absent']]]                     $ca_status_whitelist             = undef,
  Optional[Variant[Stdlib::AbsolutePath, Enum['absent']]]                     $ruby_load_path                  = undef,
  Optional[Variant[Integer[1], Enum['auto', 'absent']]]                       $max_active_instances            = undef,
  Optional[Variant[Integer, Enum['absent']]]                                  $max_requests_per_instance       = undef,
  Optional[Variant[Integer[1000], Enum['absent']]]                            $borrow_timeout                  = undef,
  Optional[Boolean]                                                           $environment_class_cache_enabled = undef,
  Optional[Pattern['^\d+\.\d+$']]                                             $compat_version                  = undef,
  Optional[Enum['off', 'jit', 'force', 'absent']]                             $compile_mode                    = undef,
  Optional[Variant[Array[Pupmod::Master::SSLProtocols, 1], Enum['absent']]]   $ssl_protocols                   = undef,
  Optional[Variant[Array[Pupmod::Master::SSLCipherSuites, 1], Enum['absent']]] $ssl_cipher_suites              = undef,
  Optional[Boolean]                                                           $enable_profiler                 = undef,
  Optional[Variant[Pupmod::ProfilingMode, Enum['absent']]]                    $profiling_mode                  = undef,
  Optional[Variant[Stdlib::AbsolutePath, Enum['absent']]]                     $profiler_output_file            = undef,
  Optional[Variant[Array[Simplib::Hostname], Enum['absent']]]                 $admin_api_whitelist             = undef,
  Optional[String[1]]                                                         $admin_api_mountpoint            = undef,
  Optional[Boolean]                                                           $log_to_file                     = undef,
  Optional[Variant[Boolean, Enum['absent']]]                                  $strict_hostname_checking        = undef,
  Boolean                                                                     $cve_2020_7942_warning           = true,
  Optional[Boolean]                                                           $syslog                          = simplib::lookup('simp_options::syslog', { 'default_value' => undef }),
  String                                                                      $syslog_facility                 = 'LOCAL6',
  String                                                                      $syslog_message_format           = '%logger[%thread]: %msg',
  Optional[Pupmod::LogLevel]                                                  $log_level                       = undef,
  Optional[Array[String[1]]]                                                  $autosign_hosts                  = undef,
  Hash[Pattern['^(\*\.)?\S+$'], Pupmod::EntryOptions]                          $autosign_entries                = {},
  String                                                                      $package_ensure                  = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' }),
  Optional[Boolean]                                                           $enable_analytics                = undef,
  Optional[Hash[String[1], Data]]                                             $server_webserver_options        = undef,
  Optional[Hash[String[1], Data]]                                             $ca_webserver_options            = undef,
  Optional[Hash[String[1], Hash[String[1], Data]]]                            $extra_webserver_sections        = undef,
  Boolean                                                                     $mock                            = false
) inherits pupmod {
  # In Puppet 6.19 the section "master" was renamed to "server" in Puppet.settings.
  # pick is used here to determine correct value for backwards compatability
  $_puppet_user = pick($facts.dig('puppet_settings','server','user'),$facts.dig('puppet_settings','master','user'))
  $_puppet_group = $pupmod::puppet_group

  unless $mock {
    include 'pupmod::master::install'
    include 'pupmod::master::sysconfig'
    include 'pupmod::master::config'
    include 'pupmod::master::reports'
    include 'pupmod::master::base'
    include 'pupmod::master::service'
    include 'pupmod::master::generate_types'

    Class['pupmod::master::install'] ~> Class['pupmod::master::service']
    Class['pupmod::master::sysconfig'] ~> Class['pupmod::master::service']
    Class['pupmod::master::config'] ~> Class['pupmod::master::service']
    Class['pupmod::master::service'] ~> Class['pupmod::master::generate_types']

    if $_puppet_group =~ NotUndef {
      $_conf_base = dirname($confdir)

      file {
        default:
          ensure  => 'directory',
          owner   => 'root',
          group   => $_puppet_group,
          require => Class['pupmod::master::install'];

        [$confdir, $codedir]: mode => '0640';

        # For Puppet 7+
        $_conf_base: mode => '0660';

        # Mode is managed by puppet itself
        [$rundir, $ssldir]: owner => $_puppet_user;
      }
    }

    # Settings for the [server] section of puppet.conf, by resource title
    $_server_settings = {
      'master_environmentpath' => ['environmentpath', $environmentpath],
      'master_daemonize'       => ['daemonize', $daemonize],
      'master_masterport'      => ['masterport', $masterport],
      'master_ca_port'         => ['ca_port', $ca_port],
      'ca_ttl'                 => ['ca_ttl', $ca_ttl],
      'keylength'              => ['keylength', $keylength],
    }

    # Settings for the [main] section of puppet.conf, by resource title
    $_main_settings = {
      'freeze_main'              => ['freeze_main', $freeze_main],
      'strict_hostname_checking' => ['strict_hostname_checking', $strict_hostname_checking],
    }

    $_sections = {
      'server' => $_server_settings,
      'main'   => $_main_settings,
    }

    $_sections.each |String[1] $section, Hash $settings| {
      $settings.each |String[1] $title, Array $setting_value| {
        $_value = $setting_value[1]

        if $_value =~ NotUndef {
          $_ensure = $_value ? {
            'absent' => 'absent',
            default  => 'present',
          }

          pupmod::conf { $title:
            ensure  => $_ensure,
            section => $section,
            confdir => $puppet_confdir,
            setting => $setting_value[0],
            value   => $_value,
            notify  => Class['pupmod::master::service'],
          }
        }
      }
    }

    if ($strict_hostname_checking == false) and $cve_2020_7942_warning {
      notify { 'CVE-2020-7942':
        message => "Setting '${module_name}::master::strict_hostname_checking' to 'false' enables CVE-2020-7942.\n\nSet '${module_name}::master::cve_2020_7942_warning' to 'false' to disable this message.",
      }
    }

    if $auditd {
      include 'auditd'

      auditd::rule { 'puppet_master':
        content => epp("${module_name}/puppet-auditd-rules"),
      }
    }

    if $firewall {
      include 'iptables'

      # puppetserver listens on 8140 unless told otherwise
      $_firewall_masterport = $masterport ? {
        Integer => $masterport,
        default => 8140,
      }

      if $enable_master != false {
        iptables::listen::tcp_stateful { 'allow_puppet':
          order        => 11,
          trusted_nets => $trusted_nets,
          dports       => $_firewall_masterport,
        }
      }

      if ($enable_ca != false) and ($ca_port =~ Integer) {
        iptables::listen::tcp_stateful { 'allow_puppetca':
          order        => 11,
          trusted_nets => $trusted_nets,
          dports       => $ca_port,
        }
      }
    }

    if $autosign_hosts =~ NotUndef {
      deprecation('pupmod::master::autosign_hosts', 'pupmod::master::autosign_hosts is deprecated. Use pupmod::master::autosign_entries instead.', false)
    }

    # The deprecated Array is applied last, so a site's existing data still wins
    $_autosign = $autosign_entries.reduce({}) |$memo, $entry| {
      $memo + { $entry[0] => pick($entry[1]['ensure'], 'present') }
    } + pick($autosign_hosts, []).reduce({}) |$memo, $entry| {
      $memo + { $entry => 'present' }
    }

    $_autosign.each |String[1] $autosign_host, Enum['present', 'absent'] $autosign_ensure| {
      ensure_resource('pupmod::master::autosign', $autosign_host, { 'ensure' => $autosign_ensure })
    }
  }
}
