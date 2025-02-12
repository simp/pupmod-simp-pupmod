# @summary Install the puppetserver
#
class pupmod::master::install(
  String[1] $package_name = pupmod::server_distribution() ? { 'PE' => 'pe-puppetserver', default => 'puppetserver'},
  String[1] $package_ensure = pick(getvar('pupmod::master::package_ensure'), 'installed')
) {
  assert_private()

  if pupmod::server_distribution() != 'PE' {
    package { $package_name:
      ensure => $package_ensure,
    }
  }
}
