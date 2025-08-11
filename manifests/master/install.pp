# @summary Install the puppetserver
#
# @param package_name
# @param package_ensure
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
        # If the openvox_release_url is not provided, calculate the release package url
        $_openvox_release_url = if $facts['os']['name'] == 'Amazon' and $facts['os']['release']['major'] == '2' {
          "${pupmod::openvox_base_url}/openvox8-release-amazon-2.noarch.rpm "
        } else {
          "${pupmod::openvox_base_url}/openvox8-release-el-${facts['os']['release']['major']}.noarch.rpm"
        }
        package { $_openvox_release_url:
          ensure => $package_ensure,
        }
        package { $package_name:
          ensure  => $package_ensure,
          require => Package[$_openvox_release_url],
        }
      }
    } else {
      package { $package_name:
        ensure => $package_ensure,
      }
    }
  }
}
