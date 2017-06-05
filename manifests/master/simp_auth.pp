# Add SIMP-specific entries to PuppetServer's auth.conf
#
# @param auth_conf_path
#   Type:    Stdlib::AbsolutePath
#   Default: /etc/puppetlabs/puppetserver/conf.d/auth.conf
#   The location to the puppet master's auth.conf
#
# @param legacy_cacerts_all
#   Type:    Boolean
#   Default: true
#   If enabled, allow access to the PKI cacerts from the legacy `pki` module from all hosts
#
# @param legacy_mcollective_all
#   Type:    Boolean
#   Default: true
#   If enabled, allow access to the mcollective cacerts from the legacy `pki` module from all hosts
#
# @param legacy_pki_keytabs_from_host
#   Type:    Boolean
#   Default: true
#   If enabled, allow access to each host's own kerberos keytabs from the legacy location
#
# @param pki_cacerts_all
#   Type:    Boolean
#   Default: true
#   If enabled, allow access to the cacerts from the `pki_files` module from all hosts
#
# @param pki_mcollective_all
#   Type:    Boolean
#   Default: true
#   If enabled, allow access to the mcollective PKI from the `pki_files` module from all hosts
#
# @param keydist_from_host
#   Type:    Boolean
#   Default: true
#   If enabled, allow access to each host's own certs from the `pki_files` module
#
# @param krb5_keytabs_from_host
#   Type:    Boolean
#   Default: true
#   If enabled, allow access to each host's own kerberos keytabs from the `pki_files` module
#
class pupmod::master::simp_auth (
  Simplib::ServerDistribution $server_distribution          = simplib::lookup('simp_options::puppet::server_distribution', { 'default_value' => 'PC1' } ),
  Stdlib::AbsolutePath        $auth_conf_path               = '/etc/puppetlabs/puppetserver/conf.d/auth.conf',
  Boolean                     $legacy_cacerts_all           = false,
  Boolean                     $legacy_mcollective_all       = false,
  Boolean                     $legacy_pki_keytabs_from_host = false,
  Boolean                     $pki_cacerts_all              = true,
  Boolean                     $pki_mcollective_all          = true,
  Boolean                     $keydist_from_host            = true,
  Boolean                     $krb5_keytabs_from_host       = true,
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

  puppet_authorization::rule { 'Allow access to the mcollective cacerts from the legacy pki module from all hosts':
    ensure               => $bool2ensure[$legacy_mcollective_all],
    match_request_path   => '^/puppet/v3/file_(metadata|content)/modules/pki/keydist/mcollective',
    match_request_type   => 'regex',
    match_request_method => ['get'],
    allow                => '*',
    sort_order           => 420,
    path                 => $auth_conf_path,
    notify               => Service[$_master_service],
  }

  puppet_authorization::rule { 'Allow access to each hosts own kerberos keytabs from the legacy location':
    ensure               => $bool2ensure[$legacy_pki_keytabs_from_host],
    match_request_path   => '^/puppet/v3/file_(metadata|content)/pki_files/keytabs/([^/]+)',
    match_request_type   => 'regex',
    match_request_method => ['get'],
    allow                => '$2',
    sort_order           => 450,
    path                 => $auth_conf_path,
    notify               => Service[$_master_service],
  }

  puppet_authorization::rule { 'Allow access to the cacerts from the pki_files module from all hosts':
    ensure               => $bool2ensure[$pki_cacerts_all],
    match_request_path   => '^/puppet/v3/file_(metadata|content)/pki_files/keydist/cacerts',
    match_request_type   => 'regex',
    match_request_method => ['get'],
    allow                => '*',
    sort_order           => 410,
    path                 => $auth_conf_path,
    notify               => Service[$_master_service],
  }

  puppet_authorization::rule { 'Allow access to the mcollective PKI from the pki_files module from all hosts':
    ensure               => $bool2ensure[$pki_mcollective_all],
    match_request_path   => '^/puppet/v3/file_(metadata|content)/pki_files/keydist/mcollective',
    match_request_type   => 'regex',
    match_request_method => ['get'],
    allow                => '*',
    sort_order           => 430,
    path                 => $auth_conf_path,
    notify               => Service[$_master_service],
  }

  puppet_authorization::rule { 'Allow access to each hosts own certs from the pki_files module':
    ensure               => $bool2ensure[$keydist_from_host],
    match_request_path   => '^/puppet/v3/file_(metadata|content)/modules/pki_files/keydist/([^/]+)',
    match_request_type   => 'regex',
    match_request_method => ['get'],
    allow                => '$2',
    sort_order           => 440,
    path                 => $auth_conf_path,
    notify               => Service[$_master_service],
  }

  puppet_authorization::rule { 'Allow access to each hosts own kerberos keytabs from the pki_files module':
    ensure               => $bool2ensure[$krb5_keytabs_from_host],
    match_request_path   => '^/puppet/v3/file_(metadata|content)/krb5_files/keytabs/([^/]+)',
    match_request_type   => 'regex',
    match_request_method => ['get'],
    allow                => '$2',
    sort_order           => 460,
    path                 => $auth_conf_path,
    notify               => Service[$_master_service],
  }

  # The puppet-agent package drops off this file for some reason, and it comes
  # as root:root. The puppetserver attempts to read this file because it exists,
  # and can't because of the permissions (puppetserver runs as puppet:puppet).
  file { '/etc/puppetlabs/puppet/auth.conf':
    ensure => absent,
    notify => Service[$_master_service]
  }
}
