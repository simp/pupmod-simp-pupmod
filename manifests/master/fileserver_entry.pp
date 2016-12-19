# Manage entries in the /etc/puppet/fileserver.conf file.
#
# @param name
#   The name of the [] segment.
#
# @param allow
#   An array of entries to add to the allow statement.
#
# @param path
#   The filesystem path to which this segment should point.
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
define pupmod::master::fileserver_entry (
  Variant[Array[Simplib::Host],Simplib::Host] $allow,
  Stdlib::AbsolutePath $path
) {

  $l_name = inline_template("<%= '${name}'.gsub('/','_') %>")

  simpcat_fragment { "fileserver+${l_name}.fileserver":
    content => template('pupmod/content/fileserver.erb')
  }

}
