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

  ensure_resource('concat', "${pupmod::confdir}/autosign.conf", {
    'ensure' => 'present',
    'owner'  => 'root',
    'group'  => 'puppet',
    'mode'   => '0640',
    'notify' => Service[$::pupmod::master::service]
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
