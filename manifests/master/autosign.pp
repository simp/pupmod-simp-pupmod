# Add an autosign entry to the puppet autosign file.
#
# Ideally, autosign will not be used in your environment. However, should you
# happen to need it
#
# Only this entry's line is managed; other lines in the file are left alone.
#
# @param name
#   The autosign entry, or a unique label for it when ``$entry`` is set
#
# @param entry
#   The autosign entry to add to the file if ``$name`` is used as a label
#
# @param ensure
#   ``absent`` removes the entry from the file
#
define pupmod::master::autosign (
  Optional[Pattern['^(\*\.)?\S+$']] $entry  = undef,
  Enum['present', 'absent']          $ensure = 'present',
) {
  include 'pupmod::master'

  $_autosign_conf = "${pupmod::confdir}/autosign.conf"

  if $entry {
    $_entry = $entry
  }
  else {
    assert_type(Pattern['^(\*\.)?\S+$'], $name) |$expected, $actual| {
      fail("'name' should be ${expected}, got '${name}'")
    }

    $_entry = $name
  }

  # file_line fails when the file is missing, so make sure it exists;
  # ownership is only managed with pupmod::puppet_group
  $_autosign_file = $pupmod::puppet_group ? {
    undef   => { 'ensure' => 'file' },
    default => {
      'ensure' => 'file',
      'owner'  => 'root',
      'group'  => $pupmod::puppet_group,
      'mode'   => '0640',
      'notify' => Class['pupmod::master::service'],
    },
  }

  ensure_resource('file', $_autosign_conf, $_autosign_file)

  file_line { "pupmod::master::autosign ${name}":
    ensure => $ensure,
    path   => $_autosign_conf,
    line   => $_entry,
    notify => Class['pupmod::master::service'],
  }
}
