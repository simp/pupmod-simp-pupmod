# Add SIMP-specific entries to PuppetServer's auth.conf
#
# Each rule is only managed when its Boolean is set: `true` adds the rule and
# `false` removes it. `undef` leaves it alone.
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
# @param remove_legacy_auth_conf
#   Remove the legacy `/etc/puppetlabs/puppet/auth.conf`, keeping a backup in
#   the filebucket.
#
#   The agent package drops off this file, and puppetserver fails to read it
#   because it is owned by root.
#
class pupmod::master::simp_auth (
  Stdlib::AbsolutePath                                          $auth_conf_path               = '/etc/puppetlabs/puppetserver/conf.d/auth.conf',
  Optional[Boolean]                                              $pki_mcollective_all          = undef,
  Optional[Boolean]                                              $pki_cacerts_all              = undef,
  NotUndef                                                       $pki_cacerts_all_rule         = '^/puppet/v3/file_(metadata|content)/modules/pki_files/keydist/cacerts',
  NotUndef                                                       $pki_cacerts_all_allow        = '*',
  Optional[Variant[Array[Variant[String, Hash]], String, Hash]]  $pki_cacerts_all_deny         = undef,
  Optional[Boolean]                                              $keydist_from_host            = undef,
  NotUndef                                                       $keydist_from_host_rule       = '^/puppet/v3/file_(metadata|content)/modules/pki_files/keydist/([^/]+)',
  NotUndef                                                       $keydist_from_host_allow      = '$2',
  Optional[Variant[Array[Variant[String, Hash]], String, Hash]]  $keydist_from_host_deny       = undef,
  Optional[Boolean]                                              $krb5_keytabs_from_host       = undef,
  NotUndef                                                       $krb5_keytabs_from_host_rule  = '^/puppet/v3/file_(metadata|content)/modules/krb5_files/keytabs/([^/]+)',
  NotUndef                                                       $krb5_keytabs_from_host_allow = '$2',
  Optional[Variant[Array[Variant[String, Hash]], String, Hash]]  $krb5_keytabs_from_host_deny  = undef,
  Boolean                                                        $remove_legacy_auth_conf      = false,
) {
  include 'pupmod::master'

  $_rules = {
    'Allow access to the mcollective PKI from the pki_files module from all hosts' => {
      'enable'             => $pki_mcollective_all,
      'match_request_path' => '^/puppet/v3/file_(metadata|content)/modules/pki_files/keydist/mcollective',
      'allow'              => '*',
      'deny'               => undef,
      'sort_order'         => 430,
    },
    'Allow access to the cacerts from the pki_files module from all hosts' => {
      'enable'             => $pki_cacerts_all,
      'match_request_path' => $pki_cacerts_all_rule,
      'allow'              => $pki_cacerts_all_allow,
      'deny'               => $pki_cacerts_all_deny,
      'sort_order'         => 410,
    },
    'Allow access to each hosts own certs from the pki_files module' => {
      'enable'             => $keydist_from_host,
      'match_request_path' => $keydist_from_host_rule,
      'allow'              => $keydist_from_host_allow,
      'deny'               => $keydist_from_host_deny,
      'sort_order'         => 440,
    },
    'Allow access to each hosts own kerberos keytabs from the krb5_files module' => {
      'enable'             => $krb5_keytabs_from_host,
      'match_request_path' => $krb5_keytabs_from_host_rule,
      'allow'              => $krb5_keytabs_from_host_allow,
      'deny'               => $krb5_keytabs_from_host_deny,
      'sort_order'         => 460,
    },
  }.filter |$rule, $options| { $options['enable'] =~ NotUndef }

  unless empty($_rules) {
    # Creates auth.conf when it is missing; an existing file is not replaced
    puppet_authorization { $auth_conf_path:
      version => 1,
      require => Class['pupmod::master::install'],
    }
  }

  $_rules.each |String $rule, Hash $options| {
    $_ensure = $options['enable'] ? {
      true    => 'present',
      default => 'absent',
    }

    puppet_authorization::rule { $rule:
      ensure               => $_ensure,
      match_request_path   => $options['match_request_path'],
      match_request_type   => 'regex',
      match_request_method => ['get'],
      allow                => $options['allow'],
      deny                 => $options['deny'],
      sort_order           => $options['sort_order'],
      path                 => $auth_conf_path,
      notify               => Class['pupmod::master::service'],
    }
  }

  if $remove_legacy_auth_conf {
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
}
