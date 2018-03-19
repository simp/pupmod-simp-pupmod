# Authoritatively determine the puppet server version and return `0.0.0` if one
# could not be determined.
#
# @return [String]
#   The puppet server version
#
function pupmod::server_version {
  # Authoritatively determine the puppet server version
  if defined('$::serverversion') {
    $server_version = $::serverversion
  }
  else {
    $server_version = pick(
      fact('server_facts.serverversion'),
      fact('simp_pupmod_serverversion'),
      '0.0.0'
    )
  }

  $server_version
}
