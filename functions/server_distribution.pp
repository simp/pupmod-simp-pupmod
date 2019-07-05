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
){

  # Figure out what we think we have
  if fact('pe_build') or (fact('puppet_settings.master.user') == 'pe-puppet') {
    $server_type = 'PE'
  }
  else {
    if $lookup_from_pupmod {
      # Just in case someone set these to what they *want* it to be:
      $server_type = pick(
        getvar('pupmod::server_distribution'),
        simplib::lookup('simp_options::puppet::server_distribution', { 'default_value' => 'PC1' })
      )
    }
    else {
      $server_type = simplib::lookup('simp_options::puppet::server_distribution', { 'default_value' => 'PC1' })
    }
  }

  $server_type
}
