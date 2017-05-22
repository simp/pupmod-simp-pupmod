# Add SIMP-specific entries to PuppetServer's auth.conf
#
# @param auth_conf_path
#   Type:    Stdlib::AbsolutePath
#   Default: /etc/puppetlabs/puppetserver/conf.d/auth.conf
#   The location to the puppet master's auth.conf
#
# @param pki_cacerts_all
#   Type:    Boolean
#   Default: true
#   If enabled, allow PKI cacerts files from SIMP PKI module from all hosts
#
# @param pki_mcollective_all
#   Type:    Boolean
#   Default: true
#   If enabled, allow SIMP site_files cacerts access from all hosts
#
# @param site_files_cacerts_all
#   Type:    Boolean
#   Default: true
#   If enabled, allow MCO files from SIMP PKI module access from all hosts
#
# @param site_files_mcollective_all
#   Type:    Boolean
#   Default: true
#   If enabled, allow SIMP site_files PKI mcollective access from all hosts
#
# @param keydist_from_host
#   Type:    Boolean
#   Default: true
#   If enabled, allow SIMP PKI keydist module access from specific host
#
# @param pki_keytabs_from_host
#   Type:    Boolean
#   Default: true
#   If enabled, allow SIMP site_files PKI keytabs access from specific host
#
# @param krb5_keytabs_from_host
#   Type:    Boolean
#   Default: true
#   If enabled, allow SIMP site_files krb5 keytabs access from specific host
#
class pupmod::master::simp_auth (
  Simplib::ServerDistribution $server_distribution        = simplib::lookup('simp_options::puppet::server_distribution', { 'default_value' => 'PC1' } ),
  Stdlib::AbsolutePath        $auth_conf_path             = '/etc/puppetlabs/puppetserver/conf.d/auth.conf',
  Boolean                     $pki_cacerts_all            = true,
  Boolean                     $pki_mcollective_all        = true,
  Boolean                     $site_files_cacerts_all     = true,
  Boolean                     $site_files_mcollective_all = true,
  Boolean                     $keydist_from_host          = true,
  Boolean                     $pki_keytabs_from_host      = true,
  Boolean                     $krb5_keytabs_from_host     = true,
) {

  $_master_service = $server_distribution ? {
    'PE'    => 'pe-puppetserver',
    default => 'puppetserver',
  }

  if $pki_cacerts_all {
    puppet_authorization::rule { 'Allow PKI cacerts files from SIMP PKI module from all hosts':
      match_request_path   => '^/puppet/v3/file_(metadata|content)/modules/pki/keydist/cacerts',
      match_request_type   => 'regex',
      match_request_method => ['get'],
      allow                => '*',
      sort_order           => 400,
      path                 => $auth_conf_path,
      notify               => Service[$_master_service],
    }
  }

  if $site_files_cacerts_all {
    puppet_authorization::rule { 'Allow SIMP site_files cacerts access from all hosts':
      match_request_path   => '^/puppet/v3/file_(metadata|content)/site_files/pki_files/files/keydist/cacerts',
      match_request_type   => 'regex',
      match_request_method => ['get'],
      allow                => '*',
      sort_order           => 410,
      path                 => $auth_conf_path,
      notify               => Service[$_master_service],
    }
  }

  if $pki_mcollective_all {
    puppet_authorization::rule { 'Allow MCO files from SIMP PKI module access from all hosts':
      match_request_path   => '^/puppet/v3/file_(metadata|content)/modules/pki/keydist/mcollective',
      match_request_type   => 'regex',
      match_request_method => ['get'],
      allow                => '*',
      sort_order           => 420,
      path                 => $auth_conf_path,
      notify               => Service[$_master_service],
    }
  }

  if $site_files_mcollective_all {
    puppet_authorization::rule { 'Allow SIMP site_files PKI mcollective access from all hosts':
      match_request_path   => '^/puppet/v3/file_(metadata|content)/site_files/pki_files/files/keydist/mcollective',
      match_request_type   => 'regex',
      match_request_method => ['get'],
      allow                => '*',
      sort_order           => 430,
      path                 => $auth_conf_path,
      notify               => Service[$_master_service],
    }
  }

  if $keydist_from_host {
    puppet_authorization::rule { 'Allow SIMP PKI keydist module access from specific host':
      match_request_path   => '^/puppet/v3/file_(metadata|content)/modules/pki/keydist/([^/]+)',
      match_request_type   => 'regex',
      match_request_method => ['get'],
      allow                => '$2',
      sort_order           => 440,
      path                 => $auth_conf_path,
      notify               => Service[$_master_service],
    }
  }

  if $pki_keytabs_from_host {
    puppet_authorization::rule { 'Allow SIMP site_files PKI keytabs access from specific host':
      match_request_path   => '^/puppet/v3/file_(metadata|content)/site_files/pki_files/files/keytabs/([^/]+)',
      match_request_type   => 'regex',
      match_request_method => ['get'],
      allow                => '$2',
      sort_order           => 450,
      path                 => $auth_conf_path,
      notify               => Service[$_master_service],
    }
  }

  if $krb5_keytabs_from_host {
    puppet_authorization::rule { 'Allow SIMP site_files krb5 keytabs access from specific host':
      match_request_path   => '^/puppet/v3/file_(metadata|content)/site_files/krb5_files/files/keytabs/([^/]+)',
      match_request_type   => 'regex',
      match_request_method => ['get'],
      allow                => '$2',
      sort_order           => 460,
      path                 => $auth_conf_path,
      notify               => Service[$_master_service],
    }
  }
}
