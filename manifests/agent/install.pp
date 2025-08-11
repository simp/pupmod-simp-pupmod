# @summary Install the puppetserver
#
# @param package_name
# @param package_ensure
class pupmod::agent::install (
  String[1] $package_name = $pupmod::agent_package,
  String[1] $package_ensure = pick(getvar('pupmod::package_ensure'), 'installed')
) {
  assert_private()

  package { $package_name:
    ensure => $package_ensure,
  }
}
