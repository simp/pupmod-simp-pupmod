# @summary Install the puppetserver
#
class pupmod::master::install (
  String[1] $package_name = pupmod::server_distribution() ? { 'PE' => 'pe-puppetserver', default => 'openvox-server' },
  String[1] $package_ensure = pick(getvar('pupmod::master::package_ensure'), 'installed')
) {
  assert_private()

  if pupmod::server_distribution() != 'PE' {
    if $package_name == 'openvox-server' {
      # If openvox_rpm_path is given, install it directly
      if $pupmod::openvox_rpm_path {
        package { $package_name:
          ensure => $package_ensure,
          source => $pupmod::openvox_rpm_path,
        }
      } else {
        # If the openvox_rpm_path is not provided, install the release package and then the server package
        package { $pupmod::openvox_repo_path:
          ensure => $package_ensure,
        }
        package { $package_name:
          ensure  => $package_ensure,
          require => Package[$pupmod::openvox_repo_path],
        }
      }
    } else {
      package { $package_name:
        ensure => $package_ensure,
      }
    }
  }
}
