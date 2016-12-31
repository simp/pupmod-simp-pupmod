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
# @param ca_port
#   The port where the remote CA should be contacted.
#
# @param ca_server
#   The puppet CA from which to obtain your system certificates.
#
# @param puppet_server
#   The puppet master from which to retrieve your configuration.
#
# @param auditd_support
#   If true, adds an audit record to watch sensitive Puppet directories for
#   changes by any user that is not the puppet user.
#
# @param ca_crl_pull_interval
#   How many times per day to pull the CRL down from the CA via cron.
#
#   This uses ip_to_cron to randomize the pull interval so that the CA doesn't
#   get swarmed.
#
# @param certname
#   The puppet environment name of the system.
#
#   See http://docs.puppetlabs.com/references/latest/configuration.html for
#   additional details.
#
# @param classfile
#   The path to the puppet class file.
#
#   See http://docs.puppetlabs.com/references/latest/configuration.html for
#   additional details.
#
# @param confdir
#   The path to the puppet configuration directory.
#
#   See http://docs.puppetlabs.com/references/latest/configuration.html for
#   additional details.
#
# @param daemonize
#   Whether or not to daemonize the Puppet agent.
#
#   SIMP systems do not, by default, daemonize their agents so that the
#   consumed resources can be freed for other uses and so that the cron
#   job can maintain a safe system state over time.
#
# @param enable_puppet_master
#   Whether or not to make the system a puppetmaster.
#
# @param listen
#   Whether or not to listen for incoming connections to the puppet
#   agent.
#
#   Given the ability to run puppet remotely via SSH, MCollective, or
#   many other means, we will not open this by default. If you decide to
#   enable it, don't forget to add an associated IPTables rule.
#
# @param logdir
#   The path to the puppet log directory.
#
#   See http://docs.puppetlabs.com/references/latest/configuration.html for
#   additional details.
#
# @param masterport
#   The port where the Puppet Master should be contacted.
#
# @param report
#   Whether or not to send reports to the report server. This is
#   disabled by default to allow users to reduce network load unless
#   reports are required.
#
# @param rundir
#   The path to the puppet run status directory.
#
#   See http://docs.puppetlabs.com/references/latest/configuration.html for
#   additional details.
#
# @param runinterval
#   The number of seconds between puppet runs.
#   Has no effect on the client cron job.
#
# @param splay
#   Whether or not to splay the puppet runs.
#
#   This is done by default to add some randomization to client system
#   runs on large systems.
#
# @param splaylimit
#
# @param srv_domain
#   The domain to search when using SRV records.
#
# @param ssldir
#   The path to the puppet ssl directory.
#
#   See http://docs.puppetlabs.com/references/latest/configuration.html for
#   additional details.
#
# @param syslogfacility
#   The Syslog facility to use when outputting messages from puppet.
#
# @param use_srv_records
#   Whether the server will search for SRV records in DNS for the current domain.
#
# @param haveged
#   If true, include haveged to assist with entropy generation.
#
# @param fips
#   If true, enable fips mode
#
# @param vardir
#   The directory where puppet will store all of its 'variable' data.
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class pupmod (
  Variant[Simplib::Host,Enum['$server']] $ca_server = simplib::lookup('simp_options::puppet::ca', { 'default_value' => '$server' }),
  Simplib::Port             $ca_port              = simplib::lookup('simp_options::puppet::ca_port', { 'default_value' => 8141 }),
  Simplib::Host             $puppet_server        = simplib::lookup('simp_options::puppet::server', { 'default_value'  => "puppet.${facts['domain']}" }),
  Boolean                   $auditd_support       = true,
  Integer                   $ca_crl_pull_interval = 2,
  Simplib::Host             $certname             = $facts['fqdn'],
  String                    $classfile            = '$vardir/classes.txt',
  Stdlib::AbsolutePath      $confdir              = $::pupmod::params::puppet_config['confdir'],
  Boolean                   $daemonize            = false,
  Enum['md5','sha256']      $digest_algorithm     = 'sha256',
  Boolean                   $enable_puppet_master = false,
  Stdlib::AbsolutePath      $environmentpath      = $::pupmod::params::puppet_config['environmentpath'],
  Boolean                   $listen               = false,
  Stdlib::AbsolutePath      $logdir               = $::pupmod::params::puppet_config['logdir'],
  Simplib::Port             $masterport           = 8140,
  Boolean                   $report               = false,
  Stdlib::AbsolutePath      $rundir               = $::pupmod::params::puppet_config['rundir'],
  Integer                   $runinterval          = 1800,
  Boolean                   $splay                = false,
  Optional[Integer]         $splaylimit           = undef,
  Simplib::Host             $srv_domain           = $facts['domain'],
  Stdlib::AbsolutePath      $ssldir               = $::pupmod::params::puppet_config['ssldir'],
  Simplib::Syslog::Facility $syslogfacility       = 'local6',
  Boolean                   $use_srv_records      = false,
  Stdlib::AbsolutePath      $vardir               = $::pupmod::params::puppet_config['vardir'],
  Boolean                   $haveged              = simplib::lookup('simp_options::haveged', { 'default_value'                     => false }),
  Boolean                   $fips                 = simplib::lookup('simp_options::fips', { 'default_value'                        => false }),
) inherits pupmod::params {

  validate_re($classfile,'^(\$(?!/)|/).+')
  validate_re($confdir,'^(\$(?!/)|/).+')
  validate_re($environmentpath,'^(\$(?!/)|/).+')
  validate_re($logdir,'^(\$(?!/)|/).+')
  validate_re($rundir,'^(\$(?!/)|/).+')

  if $haveged {
    include '::haveged'
  }

  $l_crl_pull_minute = ip_to_cron(1)
  $l_crl_pull_hour = ip_to_cron($ca_crl_pull_interval,24)

  if $enable_puppet_master {
    include 'pupmod::master'
    $_conf_group = 'puppet'
  }
  else {
    $_conf_group = 'root'
  }

  package { 'puppet-agent': ensure => 'latest' }

  file { $confdir:
    ensure => 'directory',
    owner  => 'root',
    group  => $_conf_group,
    mode   => '0640'
  }

  file { "${confdir}/puppet.conf":
    ensure => 'file',
    owner  => 'root',
    group  => $_conf_group,
    mode   => '0640',
    audit  => content
  }

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

  if $auditd_support {
    include 'auditd'

    auditd::add_rules { 'puppet_master':
      content => template('pupmod/puppet-auditd-rules.erb'),
    }
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
