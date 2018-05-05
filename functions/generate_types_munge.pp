# Return an Array of Strings that have the string PUPPET_ENVIRONMENTPATH
# replaced by a proper breakout of the different environments paths with the
# remaining path parts.
#
# @example with a multi-part ``environmentpath`` of ``/here:/there``
#   pupmod::generate_types_munge( ['PUPPET_ENVIRONMENTPATH'/foo/bar] )
#
#   returns: [ '/here/foo/bar', '/there/foo/bar' ]
#
# @param $to_process
#   The Array of paths to process
#
# @param $environment_paths
#   The Array of environment paths to use as the substitution for
#   ``PUPPET_ENVIRONMENTPATH``
#
# @return [Array[Stdlib::AbsolutePath]]
#   The puppet server version
#
function pupmod::generate_types_munge (
  Array[Stdlib::AbsolutePath] $to_process,
  Array[Stdlib::AbsolutePath] $environment_paths = split(pick(fact('puppet_environmentpath'), '/etc/puppetlabs/code/environments'), ':')
){

  unique(flatten(
    $environment_paths.map |String $environment_path| {
      $to_process.map |String $target| {
        regsubst($target, '/PUPPET_ENVIRONMENTPATH', $environment_path, 'G')
      }
    }
  ))
}
