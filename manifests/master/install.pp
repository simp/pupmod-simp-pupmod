# @summary Install the puppetserver
#
class pupmod::master::install(
  String[1] $package_name = simplib::lookup('simp_options::puppet::server_distribution', { 'default_value' => 'PC1' }) ? { 'PE' => 'pe-puppetserver', default => 'puppetserver'},
  String[1] $package_ensure = pick(getvar('pupmod::master::package_ensure'), 'installed')
) {
  assert_private()

  package { $package_name:
    ensure => $package_ensure
  }
}
