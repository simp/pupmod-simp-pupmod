# Provides configuration for a puppet master.
#
# @param bind_address
#   The IP address to which the Puppet Master process should bind
#
# @param ca_bind_address
#   The IP address to which the Puppet CA process should bind
#
# @param ca_port
#   The port upon which the CA should listen. This has been modified from the
#   default setting of 8140 so that it does not interfere with the certificate
#   verification of various clients.
#
# @param trusted_nets
#   An array of networks from which to allow access to the master.
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
# @param ssl_cipher_suite
#   The allowed SSL Cipher Suites to be used by the Puppet Server. The allowed
#   list is Java version dependent and you will need to check the system Java
#   documentaiton for details.
#
# @param enable_profiler
#   Whether or not to enable the Puppet Server profiler to allow for code metrics
#   gathering.
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
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class pupmod::master (
  Simplib::IP                    $bind_address          = '0.0.0.0',
  Simplib::IP                    $ca_bind_address       = '0.0.0.0',
  Simplib::Port                  $ca_port               = simplib::lookup('simp_options::puppet::ca_port', { 'default_value' => 8141 }),
  Simplib::NetList               $trusted_nets          = simplib::lookup('simp_options::trusted_nets', { 'default_value' => ['127.0.0.1','::1'] }),
  Pupmod::CaTTL                  $ca_ttl                = '10y',
  Boolean                        $daemonize             = true,
  Boolean                        $enable_ca             = true,
  Boolean                        $enable_master         = true,
  Stdlib::AbsolutePath           $environmentpath       = $::pupmod::params::puppet_config['environmentpath'],
  Boolean                        $freeze_main           = false,
  Simplib::Port                  $masterport            = 8140,
  Stdlib::AbsolutePath           $puppet_confdir        = $::pupmod::params::puppet_config['confdir'],
  Stdlib::AbsolutePath           $confdir               = $::pupmod::params::master_config['confdir'],
  Stdlib::AbsolutePath           $codedir               = $::pupmod::params::master_config['codedir'],
  Stdlib::AbsolutePath           $vardir                = $::pupmod::params::master_config['vardir'],
  Stdlib::AbsolutePath           $rundir                = $::pupmod::params::master_config['rundir'],
  Stdlib::AbsolutePath           $logdir                = $::pupmod::params::master_config['logdir'],
  Boolean                        $use_legacy_auth_conf  = true,
  Boolean                        $firewall              = simplib::lookup('simp_options::firewall', { 'default_value' => false }),
  Array[Simplib::Host]           $ca_status_whitelist   = [$facts['fqdn']],
  Optional[Stdlib::AbsolutePath] $ruby_load_path        = undef,
  Integer                        $max_active_instances  = ($facts['processors']['count'] + 2),
  Array[String]                  $ssl_protocols         = ['TLSv1', 'TLSv1.1', 'TLSv1.2'],
  Optional[Array]                $ssl_cipher_suites     = undef,
  Boolean                        $enable_profiler       = false,
  Array[Simplib::Hostname]       $admin_api_whitelist   = [$facts['fqdn']],
  String                         $admin_api_mountpoint  = '/puppet-admin-api',
  Boolean                        $log_to_file           = false,
  Boolean                        $syslog                = simplib::lookup('simp_options::syslog', { 'default_value' => true }),,
  String                         $syslog_facility       = 'LOCAL6',
  String                         $syslog_message_format = '%logger[%thread]: %msg',
  Pupmod::LogLevel               $log_level             = 'WARN'
) inherits ::pupmod::params {

  $service = 'puppetserver'

  include '::pupmod'
  include '::pupmod::master::sysconfig'
  include '::pupmod::master::reports'
  include '::pupmod::master::base'

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
    content => template('pupmod/etc/puppetserver/ca.cfg.erb'),
    require => Package[$service],
    notify  => Service[$service]
  }

  file { "${_conf_base}/logback.xml":
    ensure  => 'file',
    owner   => 'root',
    group   => 'puppet',
    mode    => '0640',
    content => template('pupmod/etc/puppetserver/logback.xml.erb'),
    require => Package[$service],
    notify  => Service[$service]
  }

  file { "${confdir}/ca.conf":
    ensure  => 'file',
    owner   => 'root',
    group   => 'puppet',
    mode    => '0640',
    content => template('pupmod/etc/puppetserver/conf.d/ca.conf.erb'),
    require => Package[$service],
    notify  => Service[$service]
  }

  if $ruby_load_path {
    file { "${confdir}/os-settings.conf":
      ensure  => 'file',
      owner   => 'root',
      group   => 'puppet',
      mode    => '0640',
      content => template('pupmod/etc/puppetserver/conf.d/os-settings.conf.erb'),
      require => Package[$service],
      notify  => Service[$service]
    }
  }

  file { "${confdir}/puppetserver.conf":
    ensure  => 'file',
    owner   => 'root',
    group   => 'puppet',
    mode    => '0640',
    content => template('pupmod/etc/puppetserver/conf.d/puppetserver.conf.erb'),
    require => Package[$service],
    notify  => Service[$service]
  }

  file { "${confdir}/web-routes.conf":
    ensure  => 'file',
    owner   => 'root',
    group   => 'puppet',
    mode    => '0640',
    content => template('pupmod/etc/puppetserver/conf.d/web-routes.conf.erb'),
    require => Package[$service],
    notify  => Service[$service]
  }

  file { "${confdir}/webserver.conf":
    ensure  => 'file',
    owner   => 'root',
    group   => 'puppet',
    mode    => '0640',
    content => template('pupmod/etc/puppetserver/conf.d/webserver.conf.erb'),
    require => Package[$service],
    notify  => Service[$service]
  }

  pupmod::conf { 'master_environmentpath':
    section => 'master',
    setting => 'environmentpath',
    value   => $environmentpath,
    notify  => Service[$service]
  }

  pupmod::conf { 'master_daemonize':
    section => 'master',
    setting => 'daemonize',
    value   => $daemonize,
    notify  => Service[$service]
  }

  pupmod::conf { 'master_masterport':
    section => 'master',
    setting => 'masterport',
    value   => $masterport,
    notify  => Service[$service]
  }

  pupmod::conf { 'master_ca':
    section => 'master',
    setting => 'ca',
    value   => $enable_ca,
    notify  => Service[$service]
  }

  pupmod::conf { 'master_ca_port':
    section => 'master',
    setting => 'ca_port',
    value   => $ca_port,
    notify  => Service[$service]
  }

  pupmod::conf { 'ca_ttl':
    section => 'master',
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
    setting => 'keylength',
    value   => $_keylength,
    notify  => Service[$service]
  }

  pupmod::conf { 'freeze_main':
    setting => 'freeze_main',
    # This is hard set for now until we can ensure that this works in all
    # potential configurations.
    value   => false,
    #value   => $freeze_main,
    notify  => Service[$service]
  }

  if $firewall {
    include '::iptables'

    if $enable_master {
      iptables::add_tcp_stateful_listen { 'allow_puppet':
        order        => '11',
        trusted_nets => $trusted_nets,
        dports       => $masterport
      }
    }

    if $enable_ca {
      iptables::add_tcp_stateful_listen { 'allow_puppetca':
        order        => '11',
        trusted_nets => $trusted_nets,
        dports       => $ca_port
      }
    }
  }

}
