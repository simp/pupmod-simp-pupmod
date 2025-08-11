# Figure out if we're running PC1 or PE puppet
#
# @param lookup_from_pupmod
#   Attempt to look up the value from `$pupmod::server_distribution`
#
# @return [String]
#   'PE' or 'PC1' as applicable
#
function pupmod::server_distribution (
  Boolean $lookup_from_pupmod = true
) {
  # In Puppet 6.19 the section "master" was renamed to "server" in Puppet.settings.
  # pick is used here to determine correct value for backwards compatability
  $_puppet_user = pick(
    $facts.dig('puppet_settings','server','user'),
    $facts.dig('puppet_settings','master','user')
  )

  if fact('pe_build') or ( $_puppet_user == 'pe-puppet') {
    $server_type = 'PE'
  }
  else {
    if $lookup_from_pupmod {
      # Just in case someone set these to what they *want* it to be:
      $server_type = pick(
        getvar('pupmod::server_distribution'),
        simplib::lookup('simp_options::puppet::server_distribution', { 'default_value' => 'openvox-server' })
      )
    }
    else {
      $server_type = simplib::lookup('simp_options::puppet::server_distribution', { 'default_value' => 'openvox-server' })
    }
  }

  $server_type
}
