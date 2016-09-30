# == Class: pupmod
#
# A class for managing Puppet configurations.
#
# This is mainly a stub class for hooking other classes along the way
# with a small bit of logic to flex the system toward being a Puppet
# master or client.
#
# All parameters are, by default, written to the [main] config block
# of the configuration file. Selective options may be written to their
# respective components as necessary for deconfliction.
#
# == Parameters
#
# [*ca_port*]
# Type: Integer
# Default: 8141
#
# The port where the remote CA should be contacted.
#
# [*ca_server*]
# Type: Hostname or IP
# Default: '$server'
#
# The puppet CA from which to obtain your system certificates.
#
# [*puppet_server*]
# Type: Hostname or IP
# Default: puppet.${::domain}
#
# The puppet master from which to retrieve your configuration.
#
# [*auditd_support*]
# Type: Boolean
# Default: true
#
# If true, adds an audit record to watch sensitive Puppet directories for
# changes by any user that is not the puppet user.
#
# [*ca_crl_pull_interval*]
# Type: Integer
# Default: 2
#
# How many times per day to pull the CRL down from the CA via cron.
#
# This uses ip_to_cron to randomize the pull interval so that the CA doesn't
# get swarmed.
#
# [*certname*]
# Type: String
# Default: $::fqdn
# The puppet environment name of the system.
#
# See http://docs.puppetlabs.com/references/latest/configuration.html for
# additional details.
#
# [*classfile*]
# Type: Path with optional permissions argument.
# Default: $vardir/classes.txt { owner = puppet, group = puppet, mode = 640 }
# The path to the puppet class file.
#
# See http://docs.puppetlabs.com/references/latest/configuration.html for
# additional details.
#
# [*confdir*]
# Type: Path with optional permissions argument.
# Default: `puppet config print confdir` { owner = root, group = puppet, mode = 660 }
# The path to the puppet configuration directory.
#
# See http://docs.puppetlabs.com/references/latest/configuration.html for
# additional details.
#
# [*daemonize*]
# Type: Boolean
#
# Whether or not to daemonize the Puppet agent.
#
# SIMP systems do not, by default, daemonize their agents so that the
# consumed resources can be freed for other uses and so that the cron
# job can maintain a safe system state over time.
#
# [*enable_puppet_master*]
# Type: Boolean
# Default: false
# Whether or not to make the system a puppetmaster.
#
# [*listen*]
# Type: Boolean
#
# Whether or not to listen for incoming connections to the puppet
# agent.
#
# Given the ability to run puppet remotely via SSH, MCollective, or
# many other means, we will not open this by default. If you decide to
# enable it, don't forget to add an associated IPTables rule.
#
# [*logdir*]
# Type: Path with optional permissions argument.
# Default: /var/log/puppet
# The path to the puppet log directory.
#
# See http://docs.puppetlabs.com/references/latest/configuration.html for
# additional details.
#
# [*masterport*]
# Type: Integer
# Default: 8140
#
# The port where the Puppet Master should be contacted.
#
# [*report*]
# Type: Boolean
# Default: false
# Whether or not to send reports to the report server. This is
# disabled by default to allow users to reduce network load unless
# reports are required.
#
# [*rundir*]
# Type: Path with optional permissions argument.
# Default: /var/run/puppet
#
# The path to the puppet run status directory.
#
# See http://docs.puppetlabs.com/references/latest/configuration.html for
# additional details.
#
# [*runinterval*]
# Type: Integer
# Default: 1800
#
# The number of seconds between puppet runs.
# Has no effect on the client cron job.
#
# [*splay*]
# Type: Boolean
# Default: false
#
# Whether or not to splay the puppet runs.
#
# This is done by default to add some randomization to client system
# runs on large systems.
#
# [*splaylimit*]
# Type: Integer
# Default: '$runinterval' (The runinterval value in the config, not a variable
# here)
#
# [*srv_domain*]
# Type: String
# Default: $::domain
#
# The domain to search when using SRV records.
#
# [*ssldir*]
# Type: Path with optional permissions argument.
# Default: $vardir/ssl
# The path to the puppet ssl directory.
#
# See http://docs.puppetlabs.com/references/latest/configuration.html for
# additional details.
#
# [*syslogfacility*]
# Type: Syslog Facility Identifier
# Default: local6
#
# The Syslog facility to use when outputting messages from puppet.
#
# [*use_srv_records*]
# Type: Boolean
# Default: false
#
# Whether the server will search for SRV records in DNS for the current domain.
#
# [*use_haveged*]
# Type: Boolean
# Default: true
#
# If true, include haveged to assist with entropy generation.
#
# [*vardir*]
# Type: Absolute Path
# Default: $vardir/puppet
#
# The directory where puppet will store all of its 'variable' data.
#
# == Authors
#
# * Trevor Vaughan <tvaughan@onyxpoint.com>
#
class pupmod (
  $ca_port              = hiera('puppet::ca_port','8141'),
  $ca_server            = hiera('puppet::ca','$server'),
  $puppet_server        = hiera('puppet::server',"puppet.${::domain}"),
  $auditd_support       = true,
  $ca_crl_pull_interval = '2',
  $certname             = $::fqdn,
  $classfile            = '$vardir/classes.txt',
  $confdir              = $::pupmod::params::puppet_config['confdir'],
  $daemonize            = false,
  $digest_algorithm     = 'sha256',
  $enable_puppet_master = false,
  $environmentpath      = $::pupmod::params::puppet_config['environmentpath'],
  $listen               = false,
  $logdir               = $::pupmod::params::puppet_config['logdir'],
  $masterport           = '8140',
  $report               = false,
  $rundir               = $::pupmod::params::puppet_config['rundir'],
  $runinterval          = '1800',
  $splay                = false,
  $splaylimit           = '',
  $srv_domain           = $::domain,
  $ssldir               = $::pupmod::params::puppet_config['ssldir'],
  $syslogfacility       = 'local6',
  $use_srv_records      = false,
  $vardir               = $::pupmod::params::puppet_config['vardir'],
  $use_haveged          = defined('$::use_haveged') ? { true => getvar('::use_haveged'), default => hiera('use_haveged', true) },
  $use_fips             = defined('$::fips_enabled') ? { true  => str2bool($::fips_enabled), default => hiera('use_fips', false) }
) {

  validate_port($ca_port)
  validate_string($ca_server)
  validate_bool($auditd_support)
  validate_integer($ca_crl_pull_interval)
  validate_string($certname)
  validate_re($classfile,'^(\$(?!/)|/).+')
  validate_re($confdir,'^(\$(?!/)|/).+')
  validate_bool($daemonize)
  validate_string($digest_algorithm)
  validate_bool($enable_puppet_master)
  validate_re($environmentpath,'^(\$(?!/)|/).+')
  validate_bool($listen)
  validate_re($logdir,'^(\$(?!/)|/).+')
  validate_port($masterport)
  validate_bool($report)
  validate_re($rundir,'^(\$(?!/)|/).+')
  validate_integer($runinterval)
  validate_bool($splay)
  if !empty($splaylimit) { validate_integer($splaylimit) }
  validate_string($srv_domain)
  validate_net_list($srv_domain)
  validate_re($ssldir,'^(\$(?!/)|/).+')
  validate_string($syslogfacility)
  validate_bool($use_srv_records)
  validate_absolute_path($vardir)
  validate_bool($use_haveged)

  compliance_map()

  if $use_haveged {
    include '::haveged'
  }

  $l_crl_pull_minute = ip_to_cron(1)
  $l_crl_pull_hour = ip_to_cron($ca_crl_pull_interval,24)

  cron { 'puppet_crl_pull':
    command => template('pupmod/commands/crl_download.erb'),
    user    => 'root',
    minute  => ip_to_cron(1),
    hour    => ip_to_cron($ca_crl_pull_interval,24)
  }

  if $daemonize {
    cron { 'puppetagent': ensure => 'absent' }

    # This has been designed to explicitly be the antithesis of the
    # cron in the 'false' statement above.
    #
    # Anything else is wholly irrelevant, since it's puppet checking
    # on itself while it's running.
    service { 'puppet':
      ensure     => 'running',
      enable     => true,
      hasrestart => true,
      hasstatus  => false,
      status     => '/usr/bin/test `/bin/ps --no-headers -fC puppetd,"puppet agent" | /usr/bin/wc -l` -ge 1 -a ! `/bin/ps --no-headers -fC puppetd,"puppet agent" | /bin/grep -c "no-daemonize"` -ge 1',
      subscribe  => File["${confdir}/puppet.conf"]
    }
  }
  else {
    include 'pupmod::agent::cron'
  }

  pupmod::conf { 'agent_daemonize':
    section => 'agent',
    setting => 'daemonize',
    value   => $daemonize
  }

  pupmod::conf { 'server':
    setting => 'server',
    value   => $puppet_server
  }

  pupmod::conf { 'ca_server':
    setting => 'ca_server',
    value   => $ca_server
  }

  pupmod::conf { 'masterport':
    setting => 'masterport',
    value   => $masterport
  }

  pupmod::conf { 'report':
    section => 'agent',
    setting => 'report',
    value   => $report
  }

  pupmod::conf { 'ca_port':
    setting => 'ca_port',
    value   => $ca_port
  }

  pupmod::conf { 'splay':
    setting => 'splay',
    value   => $splay
  }

  if !empty($splaylimit) {
    pupmod::conf { 'splaylimit':
      setting => 'splaylimit',
      value   => $splaylimit
    }
  }

  pupmod::conf { 'syslogfacility':
    setting => 'syslogfacility',
    value   => $syslogfacility
  }

  pupmod::conf { 'srv_domain':
    setting => 'srv_domain',
    value   => $srv_domain
  }

  pupmod::conf { 'certname':
    setting => 'certname',
    value   => $certname
  }

  pupmod::conf { 'vardir':
    setting => 'vardir',
    value   => $vardir
  }

  pupmod::conf { 'classfile':
    setting => 'classfile',
    value   => $classfile
  }

  pupmod::conf { 'confdir':
    setting => 'confdir',
    value   => $confdir
  }

  pupmod::conf { 'logdir':
    setting => 'logdir',
    value   => $logdir
  }

  pupmod::conf { 'rundir':
    setting => 'rundir',
    value   => $rundir
  }

  pupmod::conf { 'runinterval':
    setting => 'runinterval',
    value   => $runinterval
  }

  pupmod::conf { 'ssldir':
    setting => 'ssldir',
    value   => $ssldir
  }

  pupmod::conf { 'stringify_facts':
    setting => 'stringify_facts',
    value   => false
  }

  pupmod::conf { 'digest_algorithm':
    setting => 'digest_algorithm',
    value   => $digest_algorithm
  }

  if $enable_puppet_master {
    include 'pupmod::master'
  }

  if $auditd_support {
    include 'auditd'

    auditd::add_rules { 'puppet_master':
      content => "
        -a always,exit -F dir=${confdir} -F uid!=puppet -p wa -k Puppet_Config
        -a always,exit -F dir=${logdir} -F uid!=puppet -p wa -k Puppet_Log
        -a always,exit -F dir=${rundir} -F uid!=puppet -p wa -k Puppet_Run
        -a always,exit -F dir=${ssldir} -F uid!=puppet -p wa -k Puppet_SSL
      "
    }
  }

  file { $confdir:
    ensure => 'directory',
    owner  => 'root',
    group  => 'puppet',
    mode   => '0640'
  }

  file { "${confdir}/puppet.conf":
    ensure => 'file',
    owner  => 'root',
    group  => 'puppet',
    mode   => '0640',
    audit  => content
  }

  # This is to allow the hosts to boot faster.  It should probably be
  # re-worked.
  file { '/etc/sysconfig/puppet':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "PUPPET_EXTRA_OPTS='--daemonize'\n"
  }

  package { 'puppet-agent': ensure => 'latest' }

  # Changing SELinux booleans on a minor update is a horrible idea.
  if ( $::operatingsystem in ['RedHat','CentOS'] ) and ( $::operatingsystemmajrelease < '7' ) {
    $puppet_agent_sebool = 'puppet_manage_all_files'
  }
  else {
    $puppet_agent_sebool = 'puppetagent_manage_all_files'
  }
  if $::selinux_current_mode and $::selinux_current_mode != 'disabled' {
    selboolean { $puppet_agent_sebool :
      persistent => true,
      value      => 'on'
    }
  }
}
