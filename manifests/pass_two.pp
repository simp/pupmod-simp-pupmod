# @summary A helper defined type for adding processing to fix some issues with
# Puppet 4+ installations.
#
# @private
#
# @param namevar
# @param server_distribution
# @param confdir
# @param firewall
# @param pe_classlist
# @param pupmod_server
# @param pupmod_ca_server
# @param pupmod_ca_port
# @param pupmod_report
# @param pupmod_masterport
#
# @see comment at manifests/init.pp:244
#
define pupmod::pass_two (
  String                                 $namevar             = $name,
  Simplib::ServerDistribution            $server_distribution = pupmod::server_distribution(),
  Stdlib::AbsolutePath                   $confdir             = '/etc/puppetlabs/puppet',
  Optional[Boolean]                      $firewall            = undef,
  Hash                                   $pe_classlist        = lookup('pupmod::pe_classlist'),
  Optional[Simplib::Host]                $pupmod_server       = '1.2.3.4',
  Variant[Simplib::Host,Enum['$server']] $pupmod_ca_server    = '$server',
  Simplib::Port                          $pupmod_ca_port      = 8141,
  Boolean                                $pupmod_report       = false,
  Simplib::Port                          $pupmod_masterport   = 8140,
) {
  assert_private()

  if (defined(Class['puppet_enterprise'])) {
    $_server_distribution = 'PE'
  } else {
    $_server_distribution = $server_distribution
  }

  # These are agent specific variables, that only apply on Puppet 4+ systems:

  if ($_server_distribution == 'PC1') {
    pupmod::conf { 'server':
      confdir => $confdir,
      setting => 'server',
      value   => $pupmod_server,
    }

    pupmod::conf { 'ca_server':
      confdir => $confdir,
      setting => 'ca_server',
      value   => $pupmod_ca_server,
    }

    pupmod::conf { 'masterport':
      confdir => $confdir,
      setting => 'masterport',
      value   => $pupmod_masterport,
    }

    pupmod::conf { 'ca_port':
      confdir => $confdir,
      setting => 'ca_port',
      value   => $pupmod_ca_port,

    }
    pupmod::conf { 'report':
      section => 'agent',
      confdir => $confdir,
      setting => 'report',
      value   => $pupmod_report,
    }
  }

  $_conf_group = $facts['puppet_settings']['master']['group']

  # These two maps allow the user and service specifications to occur purely in
  # data and can be included /only/ if the node is classified into the
  # applicable groups.  this is necessary as a LEI install of PE has several
  # separate, independent roles that can be applied, not just master|agent.
  #
  # This also prevents us from passing the burden onto the user to classify
  # their nodes with two classes, one for SIMP, and one for PE.
  #
  # For safety that means that releases of SIMP are only supported on specified
  # PE releases. We need to have a matrix of supported versions.
  if ($_server_distribution == 'PE') {
    $available = $pe_classlist.map |$class, $data| {
      if (defined(Class[$class])) {
        $data['users']
      }
    }

    $notify_resources = $pe_classlist.map |$class, $data| {
      if (defined(Class[$class])) {
        if ($data['services'] != undef) {
          # lint:ignore:variable_scope
          $data['services'].map |$service| { Service[$service] }
          # lint:endignore
          }
      }
    }
    $_group_notify = unique(flatten(delete_undef_values($notify_resources)))
    $_group_members = unique(flatten(delete_undef_values($available)))
  }
  else {
    $_group_notify = undef
    $_group_members = undef
  }

  # All of those functions are required to make this 'safe' and
  # idempotent.
  group { $_conf_group:
    ensure    => 'present',
    allowdupe => false,
    tag       => 'firstrun',
    notify    => $_group_notify,
    members   => $_group_members,
  }

  # We cannot assume that every user is going to read the SIMP docs before they
  # attempt to classify a class, and we also cannot assume they know what would
  # happen if ``pupmod::master`` and ``puppet_enterprise::profile::master`` are
  # applied at the same time.
  #
  # Hell, I don't even know what would happen. But it would be bad
  # Very, very bad.
  if (defined(Class['puppet_enterprise::profile::master'])) {
    if (defined(Class['pupmod::master'])) {
      fail('pupmod::master is NOT supported on PE masters. Please remove the pupmod::master classification from hiera or the puppet console before proceeding')
    } else {
      include 'pupmod::master::sysconfig'
    }
  }
  if (defined(Class['pupmod::master'])) {
    class { 'pupmod::master::simp_auth':
      server_distribution => $_server_distribution
    }
  }

  # These items are managed on different files by both the FOSS and PE versions
  if ($_server_distribution == 'PC1') {
    $shared_mode = '0640'
    $shared_group = $_conf_group
  } elsif ($_server_distribution == 'PE') {
    $shared_mode = undef
    $shared_group = undef
  }
  file { $confdir:
    ensure => 'directory',
    owner  => 'root',
    group  => $_conf_group,
    mode   => $shared_mode
  }

  file { "${confdir}/puppet.conf":
    ensure => 'file',
    owner  => 'root',
    group  => $shared_group,
    mode   => $shared_mode
  }

  if ($_server_distribution == 'PE') {
    $pe_classlist.each |String $class, Hash $data| {
      if (defined(Class[$class])) {
        if ($data['configure_access'] == true) {
          pam::access::rule { "Add rule for ${class}": users => $data['users'], origins => ['ALL'], comment =>  'fix for init scripts that use su' }
        }
      }
    }
  }

  # Generate firewall rules on a per-class basis.  Basically, only when a node
  # is classified with a role will we poke a hole in the firewall for it
  #
  # Only create TCP rules since that's all puppet uses. But support it in the
  # data model anyway
  if ($firewall) {
    if ($_server_distribution == 'PE') {
      $pe_classlist.each |String $class, Hash $data| {
        if (defined(Class[$class])) {
          $rules = $data['firewall_rules']
          if ($rules != undef) {
            $rules.each |Hash $data| {
              case ($data['proto']) {
                'tcp' : {
                  iptables::listen::tcp_stateful { "${class} - ${data['proto']} - ${data['port']}":
                    dports => $data['port'],
                  }
                }
                default: {
                }
              }
            }
          }
        }
      }
    }
    }
}
