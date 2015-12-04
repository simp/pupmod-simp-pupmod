# == Define: pupmod::conf
#
# This is a simple define to call the Puppet INIFile class for the passed
# parameters on the puppet.conf file.
#
# The main purpose is to easily allow for a service trigger.
#
# == Parameters
#
# [*name*]
# Type: String
# Default: None
#
# A globally unique name for this resource. Will be prefixed with $modname
#
# [*setting*]
# Type: String
# Default: None
#
# The setting in the section to set
#
# [*value*]
# Type: String
# Default: None
#
# The value of the setting to be set.
#
# [*section*]
# Type: Array
# Default: ['main']
#
# The Sections of the puppet.conf to set.
#
# == Authors
#
# * Trevor Vaughan <tvaughan@onyxpoint.com>
#
define pupmod::conf (
  $setting,
  $value,
  $section = ['main'],
) {
  include '::pupmod'

  validate_string($setting)
  validate_array($section)

  $l_name = "${module_name}_${name}"

  ini_setting { $l_name:
    path    => "${::pupmod::confdir}/puppet.conf",
    section => $section,
    setting => $setting,
    # This needs to be a string to take effect!
    value   => $value
  }
}
