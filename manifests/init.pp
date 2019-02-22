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
# @param server_distribution
#   The server distribution used. This changes the configuration based on whether
#   we are using PC1 or PE
#
# @param ca_crl_pull_interval
#   NOTE: This parameter is deprecated and throws a warning if specified.
#
# @param certname
#   The puppet certificate CN name of the system.
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
# @param digest_algorithm
#   The hash Digest to use for file operations on the system.
#
# @param enable_puppet_master
#   Whether or not to make the system a puppetmaster.
#
# @param environmentpath
#   The path to the directory holding the puppet environments.
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
# @param mock
#   If true, disable all code.
#
# @param firewall
#   Whether or not firewall rules should be created
#
# @param pe_classlist
#   Hash of pe classes and assorted metadata.
#
# @param package_ensure
#   String used to specify 'latest', 'installed', or a specific version of the puppet-agent package
#
# @param set_environment
#   Set the environment on the system to the currently running environment
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class pupmod (
  Variant[Simplib::Host,Enum['$server']] $ca_server            = simplib::lookup('simp_options::puppet::ca', { 'default_value' => '$server' }),
  Simplib::Port                          $ca_port              = simplib::lookup('simp_options::puppet::ca_port', { 'default_value' => 8141 }),
  Simplib::Host                          $puppet_server        = simplib::lookup('simp_options::puppet::server', { 'default_value' => "puppet.${facts['domain']}" }),
  Simplib::ServerDistribution            $server_distribution  = simplib::lookup('simp_options::puppet::server_distribution', { 'default_value' => 'PC1' } ),
  Optional                               $ca_crl_pull_interval = undef,
  Simplib::Host                          $certname             = $facts['fqdn'],
  String[0]                              $classfile            = '$vardir/classes.txt',
  Stdlib::AbsolutePath                   $confdir              = $::pupmod::params::puppet_config['confdir'],
  Boolean                                $daemonize            = false,
  Enum['md5','sha256']                   $digest_algorithm     = 'sha256',
  Boolean                                $enable_puppet_master = false,
  Stdlib::AbsolutePath                   $environmentpath      = $::pupmod::params::puppet_config['environmentpath'],
  Boolean                                $listen               = false,
  Stdlib::AbsolutePath                   $logdir               = $::pupmod::params::puppet_config['logdir'],
  Simplib::Port                          $masterport           = 8140,
  Boolean                                $report               = false,
  Stdlib::AbsolutePath                   $rundir               = $::pupmod::params::puppet_config['rundir'],
  Integer[0]                             $runinterval          = 1800,
  Boolean                                $splay                = false,
  Optional[Integer[1]]                   $splaylimit           = undef,
  Simplib::Host                          $srv_domain           = $facts['domain'],
  Stdlib::AbsolutePath                   $ssldir               = $::pupmod::params::puppet_config['ssldir'],
  Simplib::Syslog::Facility              $syslogfacility       = 'local6',
  Boolean                                $use_srv_records      = false,
  Stdlib::AbsolutePath                   $vardir               = $::pupmod::params::puppet_config['vardir'],
  Boolean                                $haveged              = simplib::lookup('simp_options::haveged', { 'default_value' => false }),
  Boolean                                $fips                 = simplib::lookup('simp_options::fips', { 'default_value' => false }),
  Boolean                                $firewall             = simplib::lookup('simp_options::firewall', { 'default_value' => false }),
  Hash                                   $pe_classlist         = {},
  String[1]                              $package_ensure       = simplib::lookup('simp_options::package_ensure' , { 'default_value' => 'installed'}),
  Boolean                                $set_environment      = true,
  Boolean                                $mock                 = false
) inherits pupmod::params {
  unless ($mock == true) {
    simplib::assert_metadata($module_name)

    # This regex matches absolute paths or paths that begin with an existing
    # puppet configuration variable, like $vardir

    assert_type(Pattern['^(\$(?!/)|/).+'], $classfile)

    if $ca_crl_pull_interval {
      deprecation('pupmod::ca_crl_pull_interval', 'pupmod::ca_crl_pull_interval is deprecated, the CRL cron job has been removed.')
    }

    if $haveged {
      include '::haveged'
    }

    if $enable_puppet_master {
      include 'pupmod::master'
    }
    package { 'puppet-agent': ensure => $package_ensure }

    if $daemonize {
      $_puppet_service_ensure = 'running'

      cron { 'puppetagent': ensure => 'absent' }
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
      subscribe  => File["${confdir}/puppet.conf"]
    }

    pupmod::conf { 'agent_daemonize':
      section => 'agent',
      confdir => $confdir,
      setting => 'daemonize',
      value   => $daemonize
    }

    # This takes some explaining. You may be asking yourself:
    # Dear god? why? The short answer is, to make the UX for
    # PE better, we need to make no assumptions about the
    # amount of configuration the user has done before trying
    # to lay SIMP on top of PE.
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
    # The workaround is to take advantage of the fact that the puppet
    # catalog compiler takes multiple passes, a first pass for most
    # classes to be evaluated, and a second pass for resource collection
    # staetments. Basically by creating a virtual defined type and realizing
    # it immediately, we 'throw' any puppet code in the defined type into the
    # next pass of the compiler.
    #
    # Disgusting? yes. Necessary? unfortunately. This will have to be re-evaluated
    # for every major puppet release.

    @pupmod::pass_two { 'main':
      server_distribution => $server_distribution,
      confdir             => $confdir,
      firewall            => $firewall,
      pe_classlist        => $pe_classlist,
      pupmod_server       => $puppet_server,
      pupmod_ca_server    => $ca_server,
      pupmod_masterport   => $masterport,
      pupmod_ca_port      => $ca_port,
      pupmod_report       => $report,
    }
    Pupmod::Pass_two <| |>

    if !empty($splaylimit) {
      pupmod::conf { 'splaylimit':
        confdir => $confdir,
        setting => 'splaylimit',
        value   => $splaylimit
      }
    }

    if $set_environment and $environment != 'bolt_catalog' {
      pupmod::conf { 'environment':
        confdir => $confdir,
        setting => 'environment',
        value   => $environment
      }
    }

    pupmod::conf {
      default: confdir => $confdir;

      'splay':
        setting => 'splay',
        value   => $splay;
      'syslogfacility':
        setting => 'syslogfacility',
        value   => $syslogfacility;
      'srv_domain':
        setting => 'srv_domain',
        value   => $srv_domain;
      'certname':
        setting => 'certname',
        value   => $certname;
      'vardir':
        setting => 'vardir',
        value   => $vardir;
      'classfile':
        setting => 'classfile',
        value   => $classfile;
      'confdir':
        setting => 'confdir',
        value   => $confdir,;
      'logdir':
        setting => 'logdir',
        value   => $logdir;
      'rundir':
        setting => 'rundir',
        value   => $rundir;
      'runinterval':
        setting => 'runinterval',
        value   => $runinterval;
      'ssldir':
        setting => 'ssldir',
        value   => $ssldir;
      'stringify_facts':
        setting => 'stringify_facts',
        value   => false;
      'digest_algorithm':
        setting => 'digest_algorithm',
        value   => $digest_algorithm;
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
    if ( $facts['operatingsystem'] in ['RedHat','CentOS','OracleLinux'] ) and ( $facts['operatingsystemmajrelease'] < '7' ) {
      $puppet_agent_sebool = 'puppet_manage_all_files'
    }
    else {
      $puppet_agent_sebool = 'puppetagent_manage_all_files'
    }
    if $facts['selinux'] and $facts['selinux_current_mode'] and ($facts['selinux_current_mode'] != 'disabled') {
      selboolean { $puppet_agent_sebool :
        persistent => true,
        value      => 'on'
      }
    }
  }

  # Make sure OBE cron job from pupmod versions prior to 7.3.1 is removed.
  # This resource can be removed when the OBE ca_crl_pull_interval
  # parameter is removed.
  cron { 'puppet_crl_pull': ensure => 'absent' }
}
# vim: set expandtab ts=2 sw=2:
