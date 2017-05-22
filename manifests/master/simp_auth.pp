# Add SIMP-specific entries to PuppetServer's auth.conf
#
# NOTE: This is a private class.  The parameters of this class are exposed via the
# pupmod::master API.
#
class pupmod::master::simp_auth (
  Simplib::ServerDistribution $server_distribution        = $::pupmod::master::server_distribution,
  Stdlib::AbsolutePath        $auth_conf_path             = $::pupmod::master::auth_conf_path,
  Boolean                     $pki_cacerts_all            = $::pupmod::master::auth_pki_cacerts_all,
  Boolean                     $pki_mcollective_all        = $::pupmod::master::auth_pki_mcollective_all,
  Boolean                     $site_files_cacerts_all     = $::pupmod::master::auth_site_files_cacerts_all,
  Boolean                     $site_files_mcollective_all = $::pupmod::master::auth_site_files_mcollective_all,
  Boolean                     $keydist_from_host          = $::pupmod::master::auth_keydist_from_host,
  Boolean                     $pki_keytabs_from_host      = $::pupmod::master::auth_pki_keytabs_from_host,
  Boolean                     $krb5_keytabs_from_host     = $::pupmod::master::auth_krb5_keytabs_from_host,
) inherits ::pupmod::master {
  assert_private()

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
