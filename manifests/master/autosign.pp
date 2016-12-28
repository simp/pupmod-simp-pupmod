# Add an autosign entry to the puppet autosign file.
#
# Ideally, autosign will not be used in your environment. However,
# should you happen to need it
#
# @param name
#   The entry that you will be autosigning.
#
# @param entry
#   The autosign entry to add to the file.
#
define pupmod::master::autosign (
  String $entry
) {

  $l_name = inline_template("<%= '${name}'.gsub('/','_') %>")

  simpcat_fragment { "autosign+${l_name}.autosign":
    content => "${name}\n${entry}\n"
  }
}
