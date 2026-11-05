# @summary A class to manage Facter configuration
#
# @private
#
# @param facter_conf_dir Facter configuration directory
# @param facter_options Facter configuration Hash
#
class pupmod::facter::conf (
  Stdlib::Absolutepath $facter_conf_dir  = $pupmod::facter_conf_dir,
  Hash                 $facter_options   = $pupmod::facter_options
) {
  assert_private()

  file { $facter_conf_dir:
    ensure => 'directory',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  $_facter_conf = "${facter_conf_dir}/facter.conf"

  file { $_facter_conf:
    ensure => 'file',
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
  }

  $facter_options.each |String $section, Hash $config| {
    if empty($config) {
      hocon_setting { $section:
        ensure  => absent,
        path    => $_facter_conf,
        setting => $section,
        require => File[$facter_conf_dir],
      }
    } else {
      # Each key is managed on its own, so keys set elsewhere are left alone
      $config.each |String $key, $value| {
        $_ensure = $value ? {
          'absent' => 'absent',
          default  => 'present',
        }

        # hocon_setting writes a one-element Array as a scalar unless told
        $_type = $value ? {
          Array   => 'array',
          default => undef,
        }

        hocon_setting { "${section}.${key}":
          ensure  => $_ensure,
          path    => $_facter_conf,
          setting => "${section}.${key}",
          value   => $value,
          type    => $_type,
          require => File[$facter_conf_dir],
        }
      }
    }
  }
}
