# Provides configuration for a puppet master.
#
# @see https://puppet.com/docs/puppetserver/5.2/config_file_puppetserver.html
#
# @param bind_address
#   The IP address to which the Puppet Master process should bind
#
# @param ca_allow_auth_extensions
#   If true, allows the CA to sign certificates with authorization extensions.
#
# @param ca_allow_alt_names
#   If true, allows the CA to sign certificates with subject alternative names.
#
# @param ca_bind_address
#   The IP address to which the Puppet CA process should bind
#
# @param auditd
#   If true, adds an audit record to watch sensitive Puppet directories for
#   changes by any user that is not the puppet user.
#
# @param ca_port
#   The port upon which the CA should listen. This has been modified from the
#   default setting of 8140 so that it does not interfere with the certificate
#   verification of various clients.
#
# @param trusted_nets
#   An array of networks from which to allow access to the master.
#
# @param server_distribution
#   *Deprecated*: The version of the server that is being managed.
#
#   * PC1 covers everything after Puppet 3
#
# @param ca_ttl
#   This is the length after which the CA certificate will no longer be valid.
#
# @param daemonize
#   Whether or not to run the server as a daemon.
#
# @param enable_ca
#   Whether or not the system should act as a CA.
#
# @param enable_master
#   Whether or not the system should act as a Puppet Master
#
# @param environmentpath
#   The location of all directory environments.
#
# @param freeze_main
#   Whether or not code is allowed outside of site.pp or a module.
#
# @param masterport
#   The port upon which the Puppet master process will listen.
#
# @param puppet_confdir
#   The Puppet server configuration directory.
#
# @param confdir
#   The Puppet client configuration directory.
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
# @param use_legacy_auth_conf
#   Enable processing of the legacy Puppetserver auth.conf.
#
#   * This is **NOT** recommended and may cause a SIMP installation to
#     malfunction.
#
# @param max_queued_requests
#   The number of requests that may be queued against the server prior to being
#   rejected.
#
#   * Only functional on ``puppetserver`` >= 5.4.1
#
# @param max_retry_delay
#   The maximum time that a client will wait prior to giving up on the server
#   response.
#
#   * Only functional on ``puppetserver`` >= 5.4.1
#
# @param firewall
#   If enabled, will use the SIMP iptables classes to manipulate IPTables.
#
# @param ca_status_whitelist
#   An array of certificate short names which will be allowed to query the CA end
#   point of the Puppet Server
#
# @param ruby_load_path
#   The path to the system Ruby installation to use for the Puppet Server
#
# @param max_active_instances
#   The maximum number of active JRuby instances to be run by the Puppet Server
#
# @param max_requests_per_instance
#   The number of requests a given JRuby instance will process prior to being
#   stopped.
#
# @param borrow_timeout
#   The timeout, in milliseconds, when attempting to borrow an instance from
#   the JRuby pool.
#
# @param environment_class_cache_enabled
#   Maintain a cache in conjucntion with the use of the ``environment_classes``
#   API.
#
# @param compat_version
#   Set the JRuby compat version
#
#   * Has no effect on ``puppetserver`` >= 5.0
#
# @param compile_mode
#   Set the JRuby ``CompileMode``.
#
# @param ssl_protocols
#   Default: ['TLSv1','TLSv1.1','TLSv1.2']
#   The protocols that are allowed for communication with the Puppet Server. See
#   the ssl-protocols documentaiton for the Puppet Server for additional details.
#
# @param ssl_cipher_suites
#   The allowed SSL Cipher Suites to be used by the Puppet Server. The allowed
#   list is Java version dependent and you will need to check the system Java
#   documentaiton for details.
#
# @param enable_profiler
#   Whether or not to enable the Puppet Server profiler to allow for code metrics
#   gathering.
#
# @param profiling_mode
#   The JRuby profiling mode to use when profiling the server.
#
#   * Only functional on ``puppetserver`` >= 5.4.1
#
# @param profiling_output_file
#   The file to use when outputting server profiling information
#
#   * Only functional on ``puppetserver`` >= 5.4.1
#
# @param admin_api_whitelist
#   A list of X.509 certificate names that should be allowed to access the Puppet
#   Server's administrative API.
#
# @param admin_api_mountpoint
#   The endpoint for the Puppet Servers adminstrative API. Changing this may
#   break external utilities.
#
# @param log_to_file
#   If true, log to system log files at /var/log/puppetserver.
#
# @param syslog
#   If true, log to the local system logger over UDP port 514.
#
# @param syslog_facility
#   The syslog facility to which to report if using syslog.
#
# @param syslog_message_format
#   The Logback compatible syslog message format. For more information, see the
#   Logback documentation for 'SuffixPattern'.
#
# @param log_level
#   Type: One of ['TRACE','DEBUG','INFO','WARN','ERROR','OFF']
#   A syslog severity string limiting the messages reported. Be aware that
#   anything above 'WARN' will provide a massive amount of logs at each puppet
#   run.
#
# @param autosign_hosts
#   An array of hosts or host globs to add to the master's ``autosign.conf`` file
#
#   * WARNING: If set, will be **authoritative** and overwrite the entire file!
#
# @param package_ensure
#   String used to specify either 'latest', 'installed', or a specific version
#   of the puppetserver package
#
# @param server_webserver_options
#   A ``Hash`` of ``String,String`` pairs that will be added as HOCON formatted
#   options to the ``base`` section of the server's webserver.conf
#   configuration.
#
#   This is completely unvalidated and is present to allow setting many of the
#   more escoteric options that can be found in the webserver configuration
#   documentation at
#   https://github.com/puppetlabs/trapperkeeper-webserver-jetty9/blob/master/doc/jetty-config.md
#
#   The results will be printed in the order that they are defined as `key:
#   value` with no additional formatting so take care to ensure that your
#   values are in proper HOCON format per
#   https://github.com/lightbend/config/blob/master/HOCON.md
#
# @param ca_webserver_options
#   A ``Hash`` of ``String,String`` pairs that will be added as HOCON formatted
#   options to the ``ca`` section of the server's webserver.conf configuration.
#
#   This is completely unvalidated and is present to allow setting many of the
#   more escoteric options that can be found in the webserver configuration
#   documentation at
#   https://github.com/puppetlabs/trapperkeeper-webserver-jetty9/blob/master/doc/jetty-config.md
#
#   The results will be printed in the order that they are defined as `key:
#   value` with no additional formatting so take care to ensure that your
#   values are in proper HOCON format per
#   https://github.com/lightbend/config/blob/master/HOCON.md
#
# @param extra_webserver_sections
#   A ``Hash`` using the following format to express the full contents of a
#   webserver configuration section with options as defined in
#   https://github.com/puppetlabs/trapperkeeper-webserver-jetty9/blob/master/doc/jetty-config.md
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
#   Result Example:
#
#   ```json
#   webserver: {
#     ...pre-existing material...
#     section1_name: {
#       ssl-port: 1234
#     }
#     section2_name: {
#       ssl-port: 2345
#     }
#   }
#   ```
#
#   This is completely unvalidated and is present to allow setting many of the
#   more escoteric options that can be found in the webserver configuration
#   documentation at
#   https://github.com/puppetlabs/trapperkeeper-webserver-jetty9/blob/master/doc/jetty-config.md
#
#   The results will be printed in the order that they are defined as `key:
#   value` with no additional formatting so take care to ensure that your
#   values are in proper HOCON format per
#   https://github.com/lightbend/config/blob/master/HOCON.md
#
# @param mock
#   DO NOT USE. needed for rspec testing
#
# @author https://github.com/simp/pupmod-simp-pupmod/graphs/contributors
#
class pupmod::master (
  Simplib::IP                                         $bind_address                    = '0.0.0.0',
  Boolean                                             $ca_allow_auth_extensions        = false,
  Boolean                                             $ca_allow_alt_names              = false,
  Simplib::IP                                         $ca_bind_address                 = '0.0.0.0',
  Boolean                                             $auditd                          = simplib::lookup('simp_options::auditd', { 'default_value' => false }),
  Simplib::Port                                       $ca_port                         = simplib::lookup('simp_options::puppet::ca_port', { 'default_value' => 8141 }),
  Simplib::NetList                                    $trusted_nets                    = simplib::lookup('simp_options::trusted_nets', { 'default_value' => ['127.0.0.1','::1'] }),
  String                                              $server_distribution             = simplib::lookup('simp_options::puppet::server_distribution', { 'default_value' => 'PC1' } ),
  Pupmod::CaTTL                                       $ca_ttl                          = '10y',
  Boolean                                             $daemonize                       = true,
  Boolean                                             $enable_ca                       = true,
  Boolean                                             $enable_master                   = true,
  Stdlib::AbsolutePath                                $environmentpath                 = $pupmod::environmentpath,
  Boolean                                             $freeze_main                     = false,
  Simplib::Port                                       $masterport                      = 8140,
  Stdlib::AbsolutePath                                $puppet_confdir                  = $pupmod::confdir,
  Stdlib::AbsolutePath                                $confdir                         = $pupmod::params::master_config['confdir'],
  Stdlib::AbsolutePath                                $codedir                         = $pupmod::params::master_config['codedir'],
  Stdlib::AbsolutePath                                $vardir                          = $pupmod::params::master_config['vardir'],
  Stdlib::AbsolutePath                                $rundir                          = $pupmod::params::master_config['rundir'],
  Stdlib::AbsolutePath                                $logdir                          = $pupmod::params::master_config['logdir'],
  Stdlib::AbsolutePath                                $ssldir                          = $pupmod::ssldir,
  Boolean                                             $use_legacy_auth_conf            = false,
  Integer[0]                                          $max_queued_requests             = 10,
  Integer[1]                                          $max_retry_delay                 = 1800,
  Boolean                                             $firewall                        = simplib::lookup('simp_options::firewall', { 'default_value' => false }),
  Array[Simplib::Host]                                $ca_status_whitelist             = [$facts['fqdn']],
  Optional[Stdlib::AbsolutePath]                      $ruby_load_path                  = undef,
  Integer[1]                                          $max_active_instances            = pupmod::max_active_instances(),
  Integer                                             $max_requests_per_instance       = 0,
  Integer[1000]                                       $borrow_timeout                  = 1200000,
  Boolean                                             $environment_class_cache_enabled = true,
  Optional[Pattern['^\d+\.\d+$']]                     $compat_version                  = undef,
  Enum['off', 'jit', 'force']                         $compile_mode                    = 'off',
  Array[Pupmod::Master::SSLProtocols]                 $ssl_protocols                   = ['TLSv1', 'TLSv1.1', 'TLSv1.2'],
  Optional[Array[Pupmod::Master::SSLCipherSuites]]    $ssl_cipher_suites               = undef,
  Boolean                                             $enable_profiler                 = false,
  Pupmod::ProfilingMode                               $profiling_mode                  = 'off',
  Stdlib::AbsolutePath                                $profiling_output_file           = "${vardir}/server_jruby_profiling",
  Array[Simplib::Hostname]                            $admin_api_whitelist             = [$facts['fqdn']],
  String                                              $admin_api_mountpoint            = '/puppet-admin-api',
  Boolean                                             $log_to_file                     = false,
  Boolean                                             $syslog                          = simplib::lookup('simp_options::syslog', { 'default_value' => false }),
  String                                              $syslog_facility                 = 'LOCAL6',
  String                                              $syslog_message_format           = '%logger[%thread]: %msg',
  Pupmod::LogLevel                                    $log_level                       = 'WARN',
  Optional[Array[String[1]]]                          $autosign_hosts                  = undef,
  String                                              $package_ensure                  = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' }),
  Optional[Hash[String[1],String[1]]]                 $server_webserver_options        = undef,
  Optional[Hash[String[1],String[1]]]                 $ca_webserver_options            = undef,
  Optional[Hash[String[1],Hash[String[1],String[1]]]] $extra_webserver_sections        = undef,
  Boolean                                             $mock                            = false
) inherits pupmod {

  $_server_version = pupmod::server_version()
  $_puppet_user = $facts['puppet_settings']['master']['user']
  $_puppet_group = $facts['puppet_settings']['master']['group']

  if ($mock == false) {
    include 'pupmod::master::install'
    include 'pupmod::master::sysconfig'
    include 'pupmod::master::reports'
    include 'pupmod::master::base'
    include 'pupmod::master::service'
    include 'pupmod::master::generate_types'

    Class['pupmod::master::install'] ~> Class['pupmod::master::service']
    Class['pupmod::master::sysconfig'] ~> Class['pupmod::master::service']
    Class['pupmod::master::service'] ~> Class['pupmod::master::generate_types']

    $_conf_base = dirname($confdir)

    file { [$_conf_base, $confdir, $codedir]:
      ensure => 'directory',
      owner  => 'root',
      group  => $_puppet_group,
      mode   => '0640'
    }

    # Mode is managed by puppet itself
    file { $rundir:
      ensure => 'directory',
      owner  => $_puppet_user,
      group  => $_puppet_group
    }

    # Mode is managed by puppet itself
    file { $ssldir:
      ensure => 'directory',
      owner  => $_puppet_user,
      group  => $_puppet_group
    }

    file {
      default:
        ensure  => 'file',
        owner   => 'root',
        group   => $_puppet_group,
        mode    => '0640',
        require => Class['pupmod::master::install'],
        notify  => Class['pupmod::master::service'];

      "${_conf_base}/services.d/ca.cfg": content => epp("${module_name}/etc/puppetserver/ca.cfg");
      "${_conf_base}/logback.xml":       content => epp("${module_name}/etc/puppetserver/logback.xml");
      "${confdir}/ca.conf":              content => epp("${module_name}/etc/puppetserver/conf.d/ca.conf");
      "${confdir}/puppetserver.conf":    content => epp("${module_name}/etc/puppetserver/conf.d/puppetserver.conf");
      "${confdir}/web-routes.conf":      content => epp("${module_name}/etc/puppetserver/conf.d/web-routes.conf");
      "${confdir}/webserver.conf":       content => epp("${module_name}/etc/puppetserver/conf.d/webserver.conf");
    }

    if $ruby_load_path {
      file { "${confdir}/os-settings.conf":
        ensure  => 'file',
        owner   => 'root',
        group   => $_puppet_group,
        mode    => '0640',
        content => epp("${module_name}/etc/puppetserver/conf.d/os-settings.conf"),
        require => Class['pupmod::master::install'],
        notify  => Class['pupmod::master::service']
      }
    }

    # `trusted_server_facts` deprecated in Puppet 5.0.0 (PUP-6112)
    $_trusted_server_facts_ensure = (versioncmp($facts['puppetversion'], '5.0')) ? {
      -1      => 'present',
      default => 'absent',
    }

    pupmod::conf { 'trusted_server_facts':
      ensure  => $_trusted_server_facts_ensure,
      confdir => $puppet_confdir,
      setting => 'trusted_server_facts',
      value   => true,
      notify  => Class['pupmod::master::service']
    }

    pupmod::conf { 'master_environmentpath':
      section => 'master',
      confdir => $puppet_confdir,
      setting => 'environmentpath',
      value   => $environmentpath,
      notify  => Class['pupmod::master::service']
    }

    pupmod::conf { 'master_daemonize':
      section => 'master',
      confdir => $puppet_confdir,
      setting => 'daemonize',
      value   => $daemonize,
      notify  => Class['pupmod::master::service']
    }

    pupmod::conf { 'master_masterport':
      section => 'master',
      confdir => $puppet_confdir,
      setting => 'masterport',
      value   => $masterport,
      notify  => Class['pupmod::master::service']
    }

    # `[master] ca` is deprecated, as of Puppet 5.5.6 (SIMP-5456), and removed
    # in Puppet 6 (PUP-9158).
    if versioncmp($facts['puppetversion'], '6.0') >= 0 {
      $_ensure_master_ca = 'absent'
    }
    elsif versioncmp($facts['puppetversion'], '5.5.6') >= 0 {
      # Puppet will emit warning messages whenever deprecated settings are
      # encountered in `puppet.conf`.  To avoid this, we remove the setting
      # if it is the same as the default `ca = true`.
      #
      # NOTE: Although the condition tests for 5.5.6 (when `ca` was marked as
      #       deprecated), due to the bug PUP-9266 this logic will not prevent
      #       deprecation warnings until the release of 5.5.8.
      $_ensure_master_ca = $enable_ca ? {
        true    => 'absent',
        default => 'present',
      }
    } else {
      $_ensure_master_ca = 'present'
    }

    pupmod::conf { 'master_ca':
      ensure  => $_ensure_master_ca,
      setting => 'ca',
      value   => $enable_ca,
      confdir => $puppet_confdir,
      section => 'master',
      notify  => Class['pupmod::master::service']
    }

    pupmod::conf { 'master_ca_port':
      section => 'master',
      confdir => $puppet_confdir,
      setting => 'ca_port',
      value   => $ca_port,
      notify  => Class['pupmod::master::service']
    }

    pupmod::conf { 'ca_ttl':
      section => 'master',
      confdir => $puppet_confdir,
      setting => 'ca_ttl',
      value   => $ca_ttl,
      notify  => Class['pupmod::master::service']
    }

    if $pupmod::fips {
      $_keylength = 2048
    }
    else {
      $_keylength = 4096
    }

    pupmod::conf { 'keylength':
      section => 'master',
      confdir => $puppet_confdir,
      setting => 'keylength',
      value   => $_keylength,
      notify  => Class['pupmod::master::service']
    }

    pupmod::conf { 'freeze_main':
      confdir => $puppet_confdir,
      setting => 'freeze_main',
      # This is hard set for now until we can ensure that this works in all
      # potential configurations.
      value   => false,
      #value   => $freeze_main,
      notify  => Class['pupmod::master::service']
    }

    if $auditd {
      include 'auditd'

      auditd::rule { 'puppet_master':
        content => epp("${module_name}/puppet-auditd-rules")
      }
    }

    if $firewall {
      include 'iptables'

      if $enable_master {
        iptables::listen::tcp_stateful { 'allow_puppet':
          order        => 11,
          trusted_nets => $trusted_nets,
          dports       => $masterport
        }
      }

      if $enable_ca {
        iptables::listen::tcp_stateful { 'allow_puppetca':
          order        => 11,
          trusted_nets => $trusted_nets,
          dports       => $ca_port
        }
      }
    }

    if $autosign_hosts {
      $autosign_hosts.each |$autosign_host| {
        ensure_resource('pupmod::master::autosign', $autosign_host)
      }
    }
  }
}
