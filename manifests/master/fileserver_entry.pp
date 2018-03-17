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
  include 'pupmod::master'

  ensure_resource('concat', "${pupmod::confdir}/fileserver.conf", {
    'ensure' => 'present',
    'owner'  => 'root',
    'group'  => 'puppet',
    'mode'   => '0640',
    'notify' => Service[$::pupmod::master::service]
  })

  concat::fragment { "pupmod::master::fileserver_entry ${name}":
    target  => "${pupmod::confdir}/fileserver.conf",
    content => epp("${module_name}/content/fileserver", { 'name' => $name, 'path' => $path, 'allow' => $allow, 'server_version' => $pupmod::master::_server_version })
  }
}
