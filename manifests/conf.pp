# This is a simple define to call the Puppet INIFile class for the passed
# parameters on the puppet.conf file.
#
# The main purpose is to easily allow for a service trigger.
#
# @param name
#   A globally unique name for this resource. Will be prefixed with $modname
#
# @param setting
#   The setting in the section to set
#
# @param value
#   The value of the setting to be set.
#
# @param confdir
#   The configuration directory holding the 'puppet.conf' file.
#
# @param section
#   The Section of the puppet.conf to set.
#
#   * If ``$setting`` is trying to be set to ``environment``, then this will be
#     forced to ``agent`` to work around various puppet command bugs.
#
#   * `master` will automatically get converted to `server`
#
#   @see https://simp-project.atlassian.net/browse/SIMP-6820
#
# @param ensure
#  Determines whether the specified setting should exist.
#
# @author https://github.com/simp/pupmod-simp-pupmod/graphs/contributors
#
define pupmod::conf (
  String                    $setting,
  Scalar                    $value,
  Stdlib::Absolutepath      $confdir,
  String                    $section  = $setting ? { 'environment' => 'agent', default => 'main' },
  Enum['present', 'absent'] $ensure   = 'present',
) {
  $l_name = "${module_name}_${name}"

  if $section == 'master' {
    $_section = 'server'
  }
  else {
    $_section = $section
  }

  ini_setting { $l_name:
    ensure  => $ensure,
    path    => "${confdir}/puppet.conf",
    section => $_section,
    setting => $setting,
    # This needs to be a string to take effect!
    value   => $value
  }

  if ( $_section == 'server' ) {
    ini_setting { "${l_name}_clean":
      ensure  => 'absent',
      path    => "${confdir}/puppet.conf",
      section => 'master',
      setting => $setting
    }
  }
}
