# @summary Install the puppet agent
#
# @param package_name
#   The name of the agent package to be installed
# @param package_ensure
#   Should be set to installed, latest, or a specific version
# @param install_options
#   Options that get passed to the package provider
class pupmod::agent::install (
  String[1]                                 $package_name    = $pupmod::agent_package,
  String[1]                                 $package_ensure  = pick(getvar('pupmod::package_ensure'), 'installed'),
  Optional[Array[Variant[String[1], Hash]]] $install_options = $pupmod::agent_package_install_options,
) {
  assert_private()

  package { $package_name:
    ensure          => $package_ensure,
    install_options => $install_options,
  }
}
