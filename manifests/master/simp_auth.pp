# Add SIMP-specific entries to PuppetServer's auth.conf
#
# For documentation about *_allow and *_deny, see the puppetserver docs
# @see https://puppet.com/docs/puppetserver/2.7/config_file_auth.html#rules
#
# @param auth_conf_path
#   The location to the puppet master's auth.conf
#
# @param pki_cacerts_all
#   Allow access to the cacerts from the `pki_files` module from all hosts
#
# @param pki_mcollective_all
#   Allow access to the mcollective PKI from the `pki_files` module from all
#   hosts
#
# @param pki_cacerts_all
#   If enabled, allow access to the cacerts from the `pki_files` module from all hosts
# @param pki_cacerts_all_rule
#   The regex rule to match requests against. The provided rule matched requests
#   coming from the `files/keydist/cacerts` directory from the pki_files module
# @param pki_cacerts_all_allow
# @param pki_cacerts_all_deny
#
# @param keydist_from_host
#   If enabled, allow access to each host's own certs from the `pki_files` module
# @param keydist_from_host_rule
#   The regex rule to match requests against. The provided rule matched requests
#   coming from the `files/keydist` directory from the pki_files module
# @param keydist_from_host_allow Rules that the puppetserver should allow
#   @see https://puppet.com/docs/puppetserver/2.7/config_file_auth.html#rules
# @param keydist_from_host_deny Rules that the puppetserver should deny
#   @see https://puppet.com/docs/puppetserver/2.7/config_file_auth.html#rules
#
# @param krb5_keytabs_from_host
#   If enabled, allow access to each host's own kerberos keytabs from the `pki_files` module
# @param krb5_keytabs_from_host_rule
#   The regex rule to match requests against. The provided rule matched requests
#   coming from the `files/keytabs` directory from the krb5_files module
# @param krb5_keytabs_from_host_allow Rules that the puppetserver should allow
#   @see https://puppet.com/docs/puppetserver/2.7/config_file_auth.html#rules
# @param krb5_keytabs_from_host_deny Rules that the puppetserver should deny
#   @see https://puppet.com/docs/puppetserver/2.7/config_file_auth.html#rules
#
#
class pupmod::master::simp_auth (
  Stdlib::AbsolutePath                  $auth_conf_path               = '/etc/puppetlabs/puppetserver/conf.d/auth.conf',
  Boolean                               $pki_mcollective_all          = true,
  Boolean                               $pki_cacerts_all              = true,
  NotUndef                              $pki_cacerts_all_rule         = '^/puppet/v3/file_(metadata|content)/modules/pki_files/keydist/cacerts',
  NotUndef                              $pki_cacerts_all_allow        = '*',
  Any                                   $pki_cacerts_all_deny         = undef,
  Boolean                               $keydist_from_host            = true,
  NotUndef                              $keydist_from_host_rule       = '^/puppet/v3/file_(metadata|content)/modules/pki_files/keydist/([^/]+)',
  NotUndef                              $keydist_from_host_allow      = '$2',
  Any                                   $keydist_from_host_deny       = undef,
  Boolean                               $krb5_keytabs_from_host       = true,
  NotUndef                              $krb5_keytabs_from_host_rule  = '^/puppet/v3/file_(metadata|content)/modules/krb5_files/keytabs/([^/]+)',
  NotUndef                              $krb5_keytabs_from_host_allow = '$2',
  Any                                   $krb5_keytabs_from_host_deny  = undef,
) {
  include 'pupmod::master::service'

  # translates the parameter, which is a boolean, to the ensure parameter for the define
  $bool2ensure = {
    true  => 'present',
    false => 'absent',
  }

  puppet_authorization::rule { 'Allow access to the mcollective PKI from the pki_files module from all hosts':
    ensure               => $bool2ensure[$pki_mcollective_all],
    match_request_path   => '^/puppet/v3/file_(metadata|content)/modules/pki_files/keydist/mcollective',
    match_request_type   => 'regex',
    match_request_method => ['get'],
    allow                => '*',
    sort_order           => 430,
    path                 => $auth_conf_path,
    notify               => Class['pupmod::master::service'],
  }

  puppet_authorization::rule { 'Allow access to the cacerts from the pki_files module from all hosts':
    ensure               => $bool2ensure[$pki_cacerts_all],
    match_request_path   => $pki_cacerts_all_rule,
    match_request_type   => 'regex',
    match_request_method => ['get'],
    allow                => $pki_cacerts_all_allow,
    deny                 => $pki_cacerts_all_deny,
    sort_order           => 410,
    path                 => $auth_conf_path,
    notify               => Class['pupmod::master::service'],
  }

  puppet_authorization::rule { 'Allow access to each hosts own certs from the pki_files module':
    ensure               => $bool2ensure[$keydist_from_host],
    match_request_path   => $keydist_from_host_rule,
    match_request_type   => 'regex',
    match_request_method => ['get'],
    allow                => $keydist_from_host_allow,
    deny                 => $keydist_from_host_deny,
    sort_order           => 440,
    path                 => $auth_conf_path,
    notify               => Class['pupmod::master::service'],
  }

  puppet_authorization::rule { 'Allow access to each hosts own kerberos keytabs from the krb5_files module':
    ensure               => $bool2ensure[$krb5_keytabs_from_host],
    match_request_path   => $krb5_keytabs_from_host_rule,
    match_request_type   => 'regex',
    match_request_method => ['get'],
    allow                => $krb5_keytabs_from_host_allow,
    deny                 => $krb5_keytabs_from_host_deny,
    sort_order           => 460,
    path                 => $auth_conf_path,
    notify               => Class['pupmod::master::service'],
  }

  # The agent package drops off this file for some reason, and it comes
  # as root:root. The puppetserver attempts to read this file because it exists,
  # and can't because of the permissions (puppetserver runs as puppet:puppet).
  # Back it up to preserve custom content on upgrade, and blow it away.
  file { '/etc/puppetlabs/puppet/auth.conf':
    ensure => absent,
    backup => true,
    notify => Class['pupmod::master::service'],
  }
}
