# A class for managing Puppet configurations.
#
# This is mainly a stub class for hooking other classes along the way
# with a small bit of logic to flex the system toward being a Puppet
# master or client.  It manages Puppet and Facter configurations.
#
# All Puppet configuration parameters are, by default, written to the
# [main] config block of the Puppet configuration file. Selective options
# may be written to their respective components as necessary for deconfliction.
#
# @param ca_port
#   The port where the remote CA should be contacted.
#
# @param ca_server
#   The puppet CA from which to obtain your system certificates.
#
# @param puppet_server
#   One or more puppet servers from which to retrieve your configuration.
#
# @param server_distribution
#   The server distribution used. This changes the configuration based on whether
#   we are using PC1 or PE
#
# @param certname
#   The puppet certificate CN name of the system.
#
#   * For authenticated remote requests, this defaults to `$trusted['certname']
#   * For all other requests (e.g., bolt), the default is `$facts['clientcert']`
#
#   For additional details, see:
#
#   * http://docs.puppetlabs.com/references/latest/configuration.html
#   * https://puppet.com/docs/puppet/latest/lang_facts_builtin_variables.html
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
# @param purge_logs
#   Purge old logs from the system.
#
# @param purge_logs_duration
#   The timeframe after which logs will be purged.
#
#   * Uses systemd tmpfiles age notation
#
# @param purge_log_dirs
#   The directories under `$logdir` to be purged.
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
# @param manage_facter_conf
#   Whether to manage the Facter configuration file.
#
# @param facter_conf_dir
#   Directory containing the Facter configuration file.
#
# @param facter_options
#   Hash of Facter configuration options.
#   - Only applies when `manage_facter_conf` is `true`.
#   - Each primary key is a section in the Facter configuration file
#     (e.g., 'facts', 'global', 'cli')
#   - When the configuration for a section is empty, that section will
#     be removed entirely from the Facter configuration file.
#   - See https://puppet.com/docs/facter/latest/configuring_facter.html
#     for details on how to configure Facter.
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
# @param agent_package
#   The name of the agent package to install.
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
  Variant[Simplib::Host,Enum['$server']]       $ca_server            = simplib::lookup('simp_options::puppet::ca', { 'default_value' => '$server' }),
  Simplib::Port                                $ca_port              = simplib::lookup('simp_options::puppet::ca_port', { 'default_value' => 8141 }),
  Variant[Simplib::Host, Array[Simplib::Host]] $puppet_server        = simplib::lookup('simp_options::puppet::server', { 'default_value' => "puppet.${facts['networking']['domain']}" }),
  Simplib::ServerDistribution                  $server_distribution  = pupmod::server_distribution(false), # Can't self-reference in this lookup
  Simplib::Host                                $certname             = ($trusted['authenticatedx'] ? {
                                                                  'remote' => $trusted['certname'],
                                                                  default  => pick($facts['clientcert'], $facts['networking']['fqdn']),
                                                                }),
  String[0]                                    $classfile            = '$vardir/classes.txt',
  Stdlib::AbsolutePath                         $confdir,
  Boolean                                      $daemonize            = false,
  Enum['md5','sha256']                         $digest_algorithm     = 'sha256',
  Boolean                                      $enable_puppet_master = false,
  Stdlib::AbsolutePath                         $environmentpath,
  Boolean                                      $listen               = false,
  Stdlib::AbsolutePath                         $logdir,
  Boolean                                      $purge_logs           = true,
  Pattern['\d+(h|m|w)']                        $purge_logs_duration  = '4w',
  Array[Stdlib::AbsolutePath]                  $purge_log_dirs       = ['/puppet*'],
  Simplib::Port                                $masterport           = 8140,
  Boolean                                      $report               = false,
  Stdlib::AbsolutePath                         $rundir,
  Integer[0]                                   $runinterval          = 1800,
  Boolean                                      $splay                = false,
  Optional[Integer[1]]                         $splaylimit           = undef,
  Simplib::Host                                $srv_domain           = $facts['networking']['domain'],
  Stdlib::AbsolutePath                         $ssldir,
  Simplib::Syslog::Facility                    $syslogfacility       = 'local6',
  Boolean                                      $use_srv_records      = false,
  Stdlib::AbsolutePath                         $vardir,
  Boolean                                      $haveged              = simplib::lookup('simp_options::haveged', { 'default_value' => false }),
  Boolean                                      $fips                 = simplib::lookup('simp_options::fips', { 'default_value' => false }),
  Boolean                                      $firewall             = simplib::lookup('simp_options::firewall', { 'default_value' => false }),
  Hash                                         $pe_classlist         = {},
  String[1]                                    $agent_package        = 'puppet-agent',
  String[1]                                    $package_ensure       = simplib::lookup('simp_options::package_ensure' , { 'default_value' => 'installed'}),
  Variant[Boolean, Enum['no_clean']]           $set_environment      = false,
  Boolean                                      $manage_facter_conf   = false,
  Stdlib::Absolutepath                         $facter_conf_dir      = '/etc/puppetlabs/facter',
  Hash                                         $facter_options,      # module data
  Boolean                                      $mock                 = false
) {

  unless $mock {
    simplib::assert_metadata($module_name)

    # This regex matches absolute paths or paths that begin with an existing
    # puppet configuration variable, like $vardir

    assert_type(Pattern['^(\$(?!/)|/).+'], $classfile)

    if $haveged {
      include '::haveged'
    }

    if $enable_puppet_master {
      include 'pupmod::master'
    }
    package { $agent_package: ensure => $package_ensure }

    if $daemonize {
      $_puppet_service_ensure = 'running'
    }
    else {
      $_puppet_service_ensure = 'stopped'
    }

    include 'pupmod::agent::cron'

    service { 'puppet':
      ensure     => $_puppet_service_ensure,
      enable     => $daemonize,
      hasrestart => true,
      hasstatus  => true,
      subscribe  => File["${confdir}/puppet.conf"],
    }

    pupmod::conf { 'agent_daemonize':
      section => 'agent',
      confdir => $confdir,
      setting => 'daemonize',
      value   => $daemonize,
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
        value   => $splaylimit,
      }
    }

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
      content => "PUPPET_EXTRA_OPTS='--daemonize'\n",
    }

    $puppet_agent_sebool = 'puppetagent_manage_all_files'
    if $facts['os']['selinux']['enabled'] and $facts['os']['selinux']['current_mode'] and ($facts['os']['selinux']['current_mode'] != 'disabled') {
      selboolean { $puppet_agent_sebool :
        persistent => true,
        value      => 'on',
      }
    }

    if $manage_facter_conf {
      include 'pupmod::facter::conf'
    }

    if $purge_logs {
      unless empty($purge_log_dirs) {
        $_purge_logdir = dirname($logdir)

        if empty($_purge_logdir) or ($_purge_logdir == '/') {
          fail("Refusing to purge top-level directories. Please ensure that ${module_name}::logdir is set to something sensible.")
        }

        $_purge_logs_content = $purge_log_dirs.map |$x| { "e ${_purge_logdir}${x} - - - ${purge_logs_duration}" }

        systemd::tmpfile { 'puppet_purge_puppet_service_logs.conf':
          content => join($_purge_logs_content, "\n"),
        }
      }
    }
    else {
      systemd::tmpfile { 'puppet_purge_puppet_service_logs': ensure => 'absent' }
    }
  }
}
