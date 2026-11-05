# @summary Manage entries in the puppet fileserver.conf file.
#
# Only this entry's `path` is managed; other mount points in the file are
# left alone.
#
# @param name
#   The name of the [] segment.
#
# @param allow
#   Unused: puppetserver controls access with its `auth.conf`.
#
# @param path
#   The filesystem path to which this segment should point.
#
# @param ensure
#   ``absent`` removes this segment's `path`
#
define pupmod::master::fileserver_entry (
  Variant[Array[Simplib::Host],Simplib::Host] $allow,
  Stdlib::AbsolutePath                        $path,
  Enum['present', 'absent']                   $ensure = 'present',
) {
  include 'pupmod::master'

  $_fileserver_conf = "${pupmod::confdir}/fileserver.conf"

  if $pupmod::puppet_group =~ NotUndef {
    ensure_resource('file', $_fileserver_conf, {
        'ensure' => 'file',
        'owner'  => 'root',
        'group'  => $pupmod::puppet_group,
        'mode'   => '0640',
        'notify' => Class['pupmod::master::service'],
    })
  }

  ini_setting { "pupmod::master::fileserver_entry ${name}":
    ensure            => $ensure,
    path              => $_fileserver_conf,
    section           => $name,
    setting           => 'path',
    value             => $path,
    key_val_separator => ' ',
    notify            => Class['pupmod::master::service'],
  }
}
