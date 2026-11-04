# @summary Install the puppetserver
#
# @param package_name
#   The name of the server package to be installed
# @param package_ensure
#   Should be set to installed, latest, or a specific version
# @param version
#   The major version of the puppetserver to be installed
# @param release_package_url
#   The url for the release package to be installed for openvox
# @param install_release_package
#   Whether to install the openvox release package from
#   `release_package_url`, which adds the openvox yum repository, before the
#   server package. Not used when `pupmod::openvox_rpm_path` is set.
class pupmod::master::install (
  String[1]       $package_name            = pupmod::server_distribution() ? { 'PE' => 'pe-puppetserver', default => 'openvox-server' },
  String[1]       $package_ensure          = pick(getvar('pupmod::master::package_ensure'), 'installed'),
  Integer         $version                 = 8,
  Stdlib::HTTPUrl $release_package_url     = "${pupmod::openvox_base_url}/openvox${version}-release-el-${facts['os']['release']['major']}.noarch.rpm",
  Boolean         $install_release_package = false,
) {
  assert_private()

  if pupmod::server_distribution() != 'PE' {
    if $package_name == 'openvox-server' {
      # If pupmod::openvox_rpm_path is given, install it directly
      if $pupmod::openvox_rpm_path {
        package { $package_name:
          ensure => $package_ensure,
          source => $pupmod::openvox_rpm_path,
        }
      } elsif $install_release_package {
        # If the pupmod::openvox_rpm_path is not provided install the release and server packages
        package { $release_package_url:
          ensure => $package_ensure,
        }
        package { $package_name:
          ensure  => $package_ensure,
          require => Package[$release_package_url],
        }
      } else {
        package { $package_name:
          ensure => $package_ensure,
        }
      }
    } else {
      package { $package_name:
        ensure => $package_ensure,
      }
    }
  }
}
