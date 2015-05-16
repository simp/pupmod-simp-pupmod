# Class: pupmod::master
#
# Provides configuration for a puppet master.
#
# == Parameters
#
# [*bind_address*]
# Type: IP Address
# Default: '0.0.0.0'
#
# The IP address to which the Puppet Master process should bind
#
# [*ca_bind_address*]
# Type: IP Address
# Default: '0.0.0.0'
#
# The IP address to which the Puppet CA process should bind
#
# [*ca_port*]
# Type: Integer
# Default: 8141
#
# The port upon which the CA should listen. This has been modified from the
# default setting of 8140 so that it does not interfere with the certificate
# verification of various clients.
#
# [*client_nets*]
# Type: Network List Array or String
#
# An array of networks from which to allow access to the master.
#
# [*ca_ttl*]
# Type: TTL Value
# Default: 10y
#
# This is the length after which the CA certificate will no longer be valid.
#
# [*daemonize*]
# Type: Boolean
# Default: true
#
# Whether or not to run the server as a daemon.
#
# [*enable_ca*]
# Type: Boolean
# Default: true
#
# Whether or not the system should act as a CA.
#
# [*enable_master*]
# Type: Boolean
# Default: true
#
# Whether or not the system should act as a Puppet Master
#
# [*environmentpath*]
# Type: Absolute Path
# Default: /etc/puppet/environments
#
# The location of all directory environments.
#
# [*freeze_main*]
# Type: Boolean
# Default: false
#
# Whether or not code is allowed outside of site.pp or a module.
#
# [*masterport*]
# Type: Integer
# Default: 8140
#
# The port upon which the Puppet master process will listen.
#
# [*trusted_node_data*]
# Type: Boolean
# Default: true
#
# Stores trusted node data in a hash called $trusted. When true also prevents
# $trusted from being overridden in any scope.
#
# [*use_iptables*]
# Type: Boolean
# Default: true
#
# If enabled, will use the SIMP iptables classes to manipulate IPTables.
#
# [*ca_status_whitelist*]
# Type: Array of Certificate short names
# Default: [$::fqdn]
#
# An array of certificate short names which will be allowed to query the CA end
# point of the Puppet Server
#
# [*ruby_load_path*]
# Type: Absolute Path
# Default: System Dependent
#
# The path to the system Ruby installation to use for the Puppet Server
#
# [*gem_home*]
# Type: Absolute Path
# Default: $::pupmod::master::vardir/jruby-gems
#
# The path to the jruby-gems directory to be used by the Puppet Server
#
# [*max_active_instances*]
# Type: Integer
# Default: $::processorcount + 2
#
# The maximum number of active JRuby instances to be run by the Puppet Server
#
# [*ssl_protocols*]
# Type: Array of Protocols
# Default: ['TLSv1','TLSv1.1','TLSv1.2']
#
# The protocols that are allowed for communication with the Puppet Server. See
# the ssl-protocols documentaiton for the Puppet Server for additional details.
#
# [*ssl_cipher_suite*]
# Type: Array of Cipher Suites
# Default: []
#
# The allowed SSL Cipher Suites to be used by the Puppet Server. The allowed
# list is Java version dependent and you will need to check the system Java
# docutmenation for details.
#
# [*enable_profiler*]
# Type: Boolean
# Default: false
#
# Whether or not to enable the Puppet Server profiler to allow for code metrics
# gathering.
#
# [*admin_api_whitelist*]
# Type: Array of Certificate Names
# Default: [$::fqdn]
#
# A list of X.509 certificate names that should be allowed to access the Puppet
# Server's administrative API.
#
# [*admin_api_mountpoint*]
# Type: String
# Default: '/puppet-admin-api'
#
# The endpoint for the Puppet Servers adminstrative API. Changing this may
# break external utilities.
#
# [*log_to_file*]
# Type: Boolean
# Default: false
#
# If true, log to system log files at /var/log/puppetserver.
#
# [*log_to_syslog*]
# Type: Boolean
# Default: true
#
# If true, log to the local system logger over UDP port 514.
#
# [*syslog_facility*]
# Type: String
# Default: 'LOCAL6'
#
# The syslog facility to which to report if using syslog.
#
# [*syslog_message_format*]
# Type: String
# Default: '%logger[%thread]: %msg'
#
# The Logback compatible syslog message format. For more information, see the
# Logback documentation for 'SuffixPattern'.
#
# [*log_level*]
# Type: One of ['TRACE','DEBUG','INFO','WARN','ERROR','OFF']
# Default: 'WARN'
#
# A syslog severity string limiting the messages reported. Be aware that
# anything above 'WARN' will provide a massive amount of logs at each puppet
# run.
#
# == Authors
#
# * Trevor Vaughan <tvaughan@onyxpoint.com>
#
class pupmod::master (
  $bind_address = '0.0.0.0',
  $ca_bind_address = '0.0.0.0',
  $ca_port = hiera('puppet::ca_port','8141'),
  $client_nets = hiera('client_nets',['127.0.0.1','::1']),
  $ca_ttl = '10y',
  $daemonize = true,
  $enable_ca = true,
  $enable_master = true,
  $environmentpath = '/etc/puppet/environments',
  $freeze_main = false,
  $masterport = '8140',
  $trusted_node_data = true,
  $use_iptables = true,
  $ca_status_whitelist = [$::fqdn],
  $ruby_load_path = '',
  $gem_home = '',
  $max_active_instances = $::processorcount + 2,
  $ssl_protocols = [ 'TLSv1', 'TLSv1.1', 'TLSv1.2' ],
  $ssl_cipher_suites = [],
  $enable_profiler = false,
  $admin_api_whitelist = [$::fqdn],
  $admin_api_mountpoint = '/puppet-admin-api',
  $log_to_file = false,
  $log_to_syslog = true,
  $syslog_facility = 'LOCAL6',
  $syslog_message_format = '%logger[%thread]: %msg',
  $log_level = 'WARN'
) {
  include '::apache'
  include '::pupmod'

  $service = 'puppetserver'

  include '::pupmod::master::sysconfig'
  include '::pupmod::master::reports'
  include '::pupmod::master::base'

  $l_client_nets = nets2cidr($client_nets)
  $l_confdir = $::pupmod::confdir

  Class['::pupmod::master::sysconfig'] ~> Service[$service]

  file { '/etc/puppetserver':
    ensure => 'directory',
    owner  => 'root',
    group  => 'puppet',
    mode   => '0640'
  }

  file { '/etc/puppetserver/conf.d':
    ensure => 'directory',
    owner  => 'root',
    group  => 'puppet',
    mode   => '0640'
  }

  file { '/etc/puppetserver/bootstrap.cfg':
    ensure  => 'file',
    owner   => 'root',
    group   => 'puppet',
    mode    => '0640',
    content => template('pupmod/etc/puppetserver/bootstrap.cfg.erb'),
    require => Package[$service],
    notify  => Service[$service]
  }

  file { '/etc/puppetserver/logback.xml':
    ensure  => 'file',
    owner   => 'root',
    group   => 'puppet',
    mode    => '0640',
    content => template('pupmod/etc/puppetserver/logback.xml.erb'),
    require => Package[$service],
    notify  => Service[$service]
  }

  file { '/etc/puppetserver/conf.d/ca.conf':
    ensure  => 'file',
    owner   => 'root',
    group   => 'puppet',
    mode    => '0640',
    content => template('pupmod/etc/puppetserver/conf.d/ca.conf.erb'),
    require => Package[$service],
    notify  => Service[$service]
  }

  if !empty($ruby_load_path) {
    file { '/etc/puppetserver/conf.d/os-settings.conf':
      ensure  => 'file',
      owner   => 'root',
      group   => 'puppet',
      mode    => '0640',
      content => template('pupmod/etc/puppetserver/conf.d/os-settings.conf.erb'),
      require => Package[$service],
      notify  => Service[$service]
    }
  }

  file { '/etc/puppetserver/conf.d/puppetserver.conf':
    ensure  => 'file',
    owner   => 'root',
    group   => 'puppet',
    mode    => '0640',
    content => template('pupmod/etc/puppetserver/conf.d/puppetserver.conf.erb'),
    require => Package[$service],
    notify  => Service[$service]
  }

  file { '/etc/puppetserver/conf.d/web-routes.conf':
    ensure  => 'file',
    owner   => 'root',
    group   => 'puppet',
    mode    => '0640',
    content => template('pupmod/etc/puppetserver/conf.d/web-routes.conf.erb'),
    require => Package[$service],
    notify  => Service[$service]
  }

  file { '/etc/puppetserver/conf.d/webserver.conf':
    ensure  => 'file',
    owner   => 'root',
    group   => 'puppet',
    mode    => '0640',
    content => template('pupmod/etc/puppetserver/conf.d/webserver.conf.erb'),
    require => Package[$service],
    notify  => Service[$service]
  }

  pupmod::conf { 'master_environmentpath':
    section => ['master'],
    setting => 'environmentpath',
    value   => $environmentpath,
    notify  => Service[$service]
  }

  pupmod::conf { 'master_daemonize':
    section => ['master'],
    setting => 'daemonize',
    value   => $daemonize,
    notify  => Service[$service]
  }

  pupmod::conf { 'master_masterport':
    section => ['master'],
    setting => 'masterport',
    value   => $masterport,
    notify  => Service[$service]
  }

  pupmod::conf { 'master_ca':
    section => ['master'],
    setting => 'ca',
    value   => $enable_ca,
    notify  => Service[$service]
  }

  pupmod::conf { 'master_ca_port':
    section => ['master'],
    setting => 'ca_port',
    value   => $ca_port,
    notify  => Service[$service]
  }

  pupmod::conf { 'ca_ttl':
    section => ['master'],
    setting => 'ca_ttl',
    value   => $ca_ttl,
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

  if $use_iptables {
    include '::iptables'

    if $enable_master {
      iptables::add_tcp_stateful_listen { 'allow_puppet':
        order       => '11',
        client_nets => $l_client_nets,
        dports      => $masterport
      }
    }

    if $enable_ca {
      iptables::add_tcp_stateful_listen { 'allow_puppetca':
        order       => '11',
        client_nets => $l_client_nets,
        dports      => $ca_port
      }
    }
  }

  validate_net_list($bind_address)
  validate_net_list($ca_bind_address)
  validate_port($ca_port)
  validate_net_list($l_client_nets)
  validate_re($ca_ttl,'^\d+y$')
  validate_bool($daemonize)
  validate_bool($enable_ca)
  validate_bool($enable_master)
  validate_absolute_path($environmentpath)
  validate_bool($freeze_main)
  validate_port($masterport)
  validate_bool($trusted_node_data)
  validate_bool($use_iptables)
  validate_array($ca_status_whitelist)
  if !empty($ruby_load_path) { validate_absolute_path($ruby_load_path) }
  if !empty($gem_home) { validate_absolute_path($gem_home) }
  validate_integer($max_active_instances)
  validate_array($ssl_protocols)
  validate_array($ssl_cipher_suites)
  validate_bool($enable_profiler)
  validate_array($admin_api_whitelist)
  validate_string($sdmin_api_mountpoint)
  validate_bool($log_to_file)
  validate_bool($log_to_syslog)
  validate_string($syslog_facility)
  validate_string($syslog_message_format)
  validate_array_member($log_level,['TRACE','DEBUG','INFO','WARN','ERROR','OFF'])
}
