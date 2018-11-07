# Provides configuration for a puppet master.
#
# @see https://puppet.com/docs/puppetserver/5.2/config_file_puppetserver.html
#
# @param bind_address
#   The IP address to which the Puppet Master process should bind
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
#   The version of the server that is being managed.
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
# @param confdir
#   The Puppet client configuration directory.
#
# @param puppet_confdir
#   The Puppet server configuration directory.
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
# @param ssl_cipher_suites
#   Set the SSL Cipher Suites for the ``puppetserver`` to use.
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
# @param package_ensure
#   String used to specify either 'latest', 'installed', or a specific version
#   of the puppetserver package
#
# @param autosign_hosts
#   An array of hosts or host globs to add to the master's ``autosign.conf`` file
#
#   * WARNING: If set, will be **authoritative** and overwrite the entire file!
#
# @param mock
#   DO NOT USE. needed for rspec testing
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class pupmod::master (
  Simplib::IP                     $bind_address                    = '0.0.0.0',
  Simplib::IP                     $ca_bind_address                 = '0.0.0.0',
  Boolean                         $auditd                          = simplib::lookup('simp_options::auditd', { 'default_value' => false }),
  Simplib::Port                   $ca_port                         = simplib::lookup('simp_options::puppet::ca_port', { 'default_value' => 8141 }),
  Simplib::NetList                $trusted_nets                    = simplib::lookup('simp_options::trusted_nets', { 'default_value' => ['127.0.0.1','::1'] }),
  String                          $server_distribution             = simplib::lookup('simp_options::puppet::server_distribution', { 'default_value' => 'PC1' } ),
  Pupmod::CaTTL                   $ca_ttl                          = '10y',
  Boolean                         $daemonize                       = true,
  Boolean                         $enable_ca                       = true,
  Boolean                         $enable_master                   = true,
  Stdlib::AbsolutePath            $environmentpath                 = $::pupmod::params::puppet_config['environmentpath'],
  Boolean                         $freeze_main                     = false,
  Simplib::Port                   $masterport                      = 8140,
  Stdlib::AbsolutePath            $puppet_confdir                  = $::pupmod::params::puppet_config['confdir'],
  Stdlib::AbsolutePath            $confdir                         = $::pupmod::params::master_config['confdir'],
  Stdlib::AbsolutePath            $codedir                         = $::pupmod::params::master_config['codedir'],
  Stdlib::AbsolutePath            $vardir                          = $::pupmod::params::master_config['vardir'],
  Stdlib::AbsolutePath            $rundir                          = $::pupmod::params::master_config['rundir'],
  Stdlib::AbsolutePath            $logdir                          = $::pupmod::params::master_config['logdir'],
  Stdlib::AbsolutePath            $ssldir                          = $::pupmod::params::puppet_config['ssldir'],
  Boolean                         $use_legacy_auth_conf            = false,
  Integer[0]                      $max_queued_requests             = 10,
  Integer[1]                      $max_retry_delay                 = 1800,
  Boolean                         $firewall                        = simplib::lookup('simp_options::firewall', { 'default_value' => false }),
  Array[Simplib::Host]            $ca_status_whitelist             = [$facts['fqdn']],
  Optional[Stdlib::AbsolutePath]  $ruby_load_path                  = undef,
  Integer[1]                      $max_active_instances            = pupmod::max_active_instances(),
  Integer                         $max_requests_per_instance       = 0,
  Integer[1000]                   $borrow_timeout                  = 1200000,
  Boolean                         $environment_class_cache_enabled = true,
  Optional[Pattern['^\d+\.\d+$']] $compat_version                  = undef,
  Enum['off', 'jit', 'force']     $compile_mode                    = 'off',
  Array[String]                   $ssl_protocols                   = ['TLSv1', 'TLSv1.1', 'TLSv1.2'],
  Optional[Array]                 $ssl_cipher_suites               = undef,
  Boolean                         $enable_profiler                 = false,
  Pupmod::ProfilingMode           $profiling_mode                  = 'off',
  Stdlib::AbsolutePath            $profiling_output_file           = "${vardir}/server_jruby_profiling",
  Array[Simplib::Hostname]        $admin_api_whitelist             = [$facts['fqdn']],
  String                          $admin_api_mountpoint            = '/puppet-admin-api',
  Boolean                         $log_to_file                     = false,
  Boolean                         $syslog                          = simplib::lookup('simp_options::syslog', { 'default_value' => false }),
  String                          $syslog_facility                 = 'LOCAL6',
  String                          $syslog_message_format           = '%logger[%thread]: %msg',
  Pupmod::LogLevel                $log_level                       = 'WARN',
  Optional[Array[String[1]]]      $autosign_hosts                  = undef,
  String                          $package_ensure                  = 'latest',
  Boolean                         $mock                            = false
) inherits ::pupmod::params {

  $_server_version = pupmod::server_version()

  if ($mock == false) {
    $service = $server_distribution ? {
      'PE'    => 'pe-puppetserver',
      default => 'puppetserver',
    }

    include '::pupmod'

    class { '::pupmod::master::sysconfig':
      service => $service,
    }

    include '::pupmod::master::reports'
    include '::pupmod::master::base'
    include '::pupmod::master::generate_types'

    Class['::pupmod::master::generate_types'] -> Service[$service]
    Class['::pupmod::master::sysconfig'] ~> Service[$service]

    $_conf_base = dirname($confdir)

    file { $_conf_base:
      ensure => 'directory',
      owner  => 'root',
      group  => 'puppet',
      mode   => '0640'
    }

    file { $confdir:
      ensure => 'directory',
      owner  => 'root',
      group  => 'puppet',
      mode   => '0640'
    }

    file { $codedir:
      ensure => 'directory',
      owner  => 'root',
      group  => 'puppet',
      mode   => '0640'
    }

    file { "${_conf_base}/services.d/ca.cfg":
      ensure  => 'file',
      owner   => 'root',
      group   => 'puppet',
      mode    => '0640',
      content => epp("${module_name}/etc/puppetserver/ca.cfg"),
      require => Package[$service],
      notify  => Service[$service]
    }

    file { "${_conf_base}/logback.xml":
      ensure  => 'file',
      owner   => 'root',
      group   => 'puppet',
      mode    => '0640',
      content => epp("${module_name}/etc/puppetserver/logback.xml"),
      require => Package[$service],
      notify  => Service[$service]
    }

    file { "${confdir}/ca.conf":
      ensure  => 'file',
      owner   => 'root',
      group   => 'puppet',
      mode    => '0640',
      content => epp("${module_name}/etc/puppetserver/conf.d/ca.conf"),
      require => Package[$service],
      notify  => Service[$service]
    }

    if $ruby_load_path {
      file { "${confdir}/os-settings.conf":
        ensure  => 'file',
        owner   => 'root',
        group   => 'puppet',
        mode    => '0640',
        content => epp("${module_name}/etc/puppetserver/conf.d/os-settings.conf"),
        require => Package[$service],
        notify  => Service[$service]
      }
    }

    file { "${confdir}/puppetserver.conf":
      ensure  => 'file',
      owner   => 'root',
      group   => 'puppet',
      mode    => '0640',
      content => epp("${module_name}/etc/puppetserver/conf.d/puppetserver.conf"),
      require => Package[$service],
      notify  => Service[$service]
    }

    file { "${confdir}/web-routes.conf":
      ensure  => 'file',
      owner   => 'root',
      group   => 'puppet',
      mode    => '0640',
      content => epp("${module_name}/etc/puppetserver/conf.d/web-routes.conf"),
      require => Package[$service],
      notify  => Service[$service]
    }

    file { "${confdir}/webserver.conf":
      ensure  => 'file',
      owner   => 'root',
      group   => 'puppet',
      mode    => '0640',
      content => epp("${module_name}/etc/puppetserver/conf.d/webserver.conf"),
      require => Package[$service],
      notify  => Service[$service]
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
      notify  => Service[$service]
    }

    pupmod::conf { 'master_environmentpath':
      section => 'master',
      confdir => $puppet_confdir,
      setting => 'environmentpath',
      value   => $environmentpath,
      notify  => Service[$service]
    }

    pupmod::conf { 'master_daemonize':
      section => 'master',
      confdir => $puppet_confdir,
      setting => 'daemonize',
      value   => $daemonize,
      notify  => Service[$service]
    }

    pupmod::conf { 'master_masterport':
      section => 'master',
      confdir => $puppet_confdir,
      setting => 'masterport',
      value   => $masterport,
      notify  => Service[$service]
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
      section => 'master',
      setting => 'ca',
      value   => $enable_ca,
      confdir => $puppet_confdir,
      ensure  => $_ensure_master_ca,
      notify  => Service[$service]
    }

    pupmod::conf { 'master_ca_port':
      section => 'master',
      confdir => $puppet_confdir,
      setting => 'ca_port',
      value   => $ca_port,
      notify  => Service[$service]
    }

    pupmod::conf { 'ca_ttl':
      section => 'master',
      confdir => $puppet_confdir,
      setting => 'ca_ttl',
      value   => $ca_ttl,
      notify  => Service[$service]
    }

    if $::pupmod::fips {
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
      notify  => Service[$service]
    }

    pupmod::conf { 'freeze_main':
      confdir => $puppet_confdir,
      setting => 'freeze_main',
      # This is hard set for now until we can ensure that this works in all
      # potential configurations.
      value   => false,
      #value   => $freeze_main,
      notify  => Service[$service]
    }

    if $auditd {
      include '::auditd'

      auditd::rule { 'puppet_master':
        content => epp("${module_name}/puppet-auditd-rules")
      }
    }

    if $firewall {
      include '::iptables'

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
