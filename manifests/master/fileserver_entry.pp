# @summary Manage entries in the /etc/puppet/fileserver.conf file.
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
define pupmod::master::fileserver_entry (
  Variant[Array[Simplib::Host],Simplib::Host] $allow,
  Stdlib::AbsolutePath $path
) {
  include 'pupmod::master'

  # In Puppet 6.19 the section "master was renamed to "server" in Puppet.settings.
  # pick is used here to determine correct value for backwards compatability
  $_puppet_group = pick($facts.dig('puppet_settings','server','group'),$facts.dig('puppet_settings','master','group'))

  ensure_resource('concat', "${pupmod::confdir}/fileserver.conf", {
    'ensure' => 'present',
    'owner'  => 'root',
    'group'  => $_puppet_group,
    'mode'   => '0640',
    'notify' => Class['pupmod::master::service']
  })

  concat::fragment { "pupmod::master::fileserver_entry ${name}":
    target  => "${pupmod::confdir}/fileserver.conf",
    content => epp("${module_name}/content/fileserver", { 'name' => $name, 'path' => $path, 'allow' => $allow, 'server_version' => $pupmod::master::_server_version })
  }
}
