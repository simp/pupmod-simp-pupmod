# == Define: pupmod::master::fileserver_entry
#
# Manage entries in the /etc/puppet/fileserver.conf file.
#
# == Parameters
#
# [*name*]
#
# The name of the [] segment.
#
# [*allow*]
#
# An array of entries to add to the allow statement.
#
# [*path*]
#
# The filesystem path to which this segment should point.
#
# == Authors
#
# * Trevor Vaughan <tvaughan@onyxpoint.com>
#
define pupmod::master::fileserver_entry (
    $allow,
    $path
) {
  # Validation first to appease rspec
  validate_array($allow)
  validate_absolute_path($path)

  $l_name = inline_template("<%= '${name}'.gsub('/','_') %>")

  concat_fragment { "fileserver+${l_name}.fileserver":
    content => template('pupmod/content/fileserver.erb')
  }

}
