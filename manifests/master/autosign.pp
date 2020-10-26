# Add an autosign entry to the puppet autosign file.
#
# Ideally, autosign will not be used in your environment. However, should you
# happen to need it
#
# @param name
#   A useful comment for the entry being signed
#
# @param entry
#   The autosign entry to add to the file if ``$name`` is used as a unique comment
#
define pupmod::master::autosign (
  Optional[Pattern['^(\*\.)?\S+$']] $entry = undef
) {
  include 'pupmod::master'

  # In Puppet 6.19 the section "master was renamed to "server" in Puppet.settings.
  # pick is used here to determine correct value for backwards compatability
  $_puppet_group = pick($facts.dig('puppet_settings','server','group'),$facts.dig('puppet_settings','master','group'))

  ensure_resource('concat', "${pupmod::confdir}/autosign.conf", {
    'ensure' => 'present',
    'owner'  => 'root',
    'group'  => $_puppet_group,
    'mode'   => '0640',
    'notify' => Class['pupmod::master::service']
  })

  if $entry {
    $_content = "# ${name}\n${entry}\n"
  }
  else {
    assert_type(Pattern['^(\*\.)?\S+$'], $name) |$expected, $actual| {
      fail("'name' should be ${expected}, got '${name}'")
    }

    $_content = "${name}\n"
  }


  concat::fragment { "pupmod::master::autosign ${name}":
    target  => "${pupmod::confdir}/autosign.conf",
    content => $_content
  }
}
