# Add SIMP-specific entries to PuppetServer's auth.conf
#
# For documentation about *_allow and *_deny, see the puppetserver docs
# @see https://puppet.com/docs/puppetserver/5.2/config_file_auth.html#allow-allow-unauthenticated-and-deny
#
# @param server_distribution Puppet open source or PE
#
# @param auth_conf_path
#   The location to the puppet master's auth.conf
#
# @param legacy_cacerts_all
#   If enabled, allow access to the PKI cacerts from the legacy `pki` module from all hosts
#
# @param legacy_pki_keytabs_from_host
#   If enabled, allow access to each host's own kerberos keytabs from the legacy location
#
# @param pki_cacerts_all
#   If enabled, allow access to the cacerts from the `pki_files` module from all hosts
# @param pki_cacerts_all_allow
# @param pki_cacerts_all_deny
#
# @param keydist_from_host
#   If enabled, allow access to each host's own certs from the `pki_files` module
# @param keydist_from_host_allow
# @param keydist_from_host_deny
#
# @param krb5_keytabs_from_host
#   If enabled, allow access to each host's own kerberos keytabs from the `pki_files` module
# @param krb5_keytabs_from_host_allow
# @param krb5_keytabs_from_host_deny
#
class pupmod::master::simp_auth (
  Simplib::ServerDistribution $server_distribution          = simplib::lookup('simp_options::puppet::server_distribution', { 'default_value' => 'PC1' } ),
  Stdlib::AbsolutePath        $auth_conf_path               = '/etc/puppetlabs/puppetserver/conf.d/auth.conf',
  Boolean                     $legacy_cacerts_all           = false,
  Boolean                     $legacy_pki_keytabs_from_host = false,
  Boolean                     $pki_cacerts_all              = true,
  NotUndef                    $pki_cacerts_all_allow        = 'certname',
  Any                         $pki_cacerts_all_deny         = undef,
  Boolean                     $keydist_from_host            = true,
  NotUndef                    $keydist_from_host_allow      = '$2',
  Any                         $keydist_from_host_deny       = undef,
  Boolean                     $krb5_keytabs_from_host       = true,
  NotUndef                    $krb5_keytabs_from_host_allow = '$2',
  Any                         $krb5_keytabs_from_host_deny  = undef,
) {

  $_master_service = $server_distribution ? {
    'PE'    => 'pe-puppetserver',
    default => 'puppetserver',
  }

  # translates the parameter, which is a boolean, to the ensure parameter for the define
  $bool2ensure = {
    true  => 'present',
    false => 'absent'
  }

  puppet_authorization::rule { 'Allow access to the PKI cacerts from the legacy pki module from all hosts':
    ensure               => $bool2ensure[$legacy_cacerts_all],
    match_request_path   => '^/puppet/v3/file_(metadata|content)/modules/pki/keydist/cacerts',
    match_request_type   => 'regex',
    match_request_method => ['get'],
    allow                => '*',
    sort_order           => 400,
    path                 => $auth_conf_path,
    notify               => Service[$_master_service],
  }

  puppet_authorization::rule { 'Allow access to each hosts own kerberos keytabs from the legacy location':
    ensure               => $bool2ensure[$legacy_pki_keytabs_from_host],
    match_request_path   => '^/puppet/v3/file_(metadata|content)/modules/pki_files/keytabs/([^/]+)',
    match_request_type   => 'regex',
    match_request_method => ['get'],
    allow                => '$2',
    sort_order           => 450,
    path                 => $auth_conf_path,
    notify               => Service[$_master_service],
  }

  puppet_authorization::rule { 'Allow access to the cacerts from the pki_files module from all hosts':
    ensure               => $bool2ensure[$pki_cacerts_all],
    match_request_path   => '^/puppet/v3/file_(metadata|content)/modules/pki_files/keydist/cacerts',
    match_request_type   => 'regex',
    match_request_method => ['get'],
    allow                => $pki_cacerts_all_allow,
    deny                 => $pki_cacerts_all_deny,
    sort_order           => 410,
    path                 => $auth_conf_path,
    notify               => Service[$_master_service],
  }

  puppet_authorization::rule { 'Allow access to each hosts own certs from the pki_files module':
    ensure               => $bool2ensure[$keydist_from_host],
    match_request_path   => '^/puppet/v3/file_(metadata|content)/modules/pki_files/keydist/([^/]+)',
    match_request_type   => 'regex',
    match_request_method => ['get'],
    allow                => $keydist_from_host_allow,
    deny                 => $keydist_from_host_deny,
    sort_order           => 440,
    path                 => $auth_conf_path,
    notify               => Service[$_master_service],
  }

  puppet_authorization::rule { 'Allow access to each hosts own kerberos keytabs from the krb5_files module':
    ensure               => $bool2ensure[$krb5_keytabs_from_host],
    match_request_path   => '^/puppet/v3/file_(metadata|content)/modules/krb5_files/keytabs/([^/]+)',
    match_request_type   => 'regex',
    match_request_method => ['get'],
    allow                => $krb5_keytabs_from_host_allow,
    deny                 => $krb5_keytabs_from_host_deny,
    sort_order           => 460,
    path                 => $auth_conf_path,
    notify               => Service[$_master_service],
  }

  # The puppet-agent package drops off this file for some reason, and it comes
  # as root:root. The puppetserver attempts to read this file because it exists,
  # and can't because of the permissions (puppetserver runs as puppet:puppet).
  # Back it up to preserve custom content on upgrade, and blow it away.
  file { '/etc/puppetlabs/puppet/auth.conf':
    ensure => absent,
    backup => true,
    notify => Service[$_master_service]
  }
}
