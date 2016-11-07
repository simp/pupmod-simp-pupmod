# Class: pupmod::params
#
# A set of defaults for the 'pupmod' namespace
#
# [*vardir*]
# Type: Absolute Path
# Default: /var/lib/puppet
#
# $java_max_memory
#   should not exceed 12G (SIMP-1128)
#
class pupmod::params (
) {
  if ($::memorysize_mb * 0.8) >= 12000 {
    $java_max_memory = '12g'
  }
  else {
    $java_max_memory = '80%'
  }
  $confdir = $facts['puppet_settings']['main']['confdir']
  $environmentpath = $facts['puppet_settings']['main']['environmentpath']
  $logdir = $facts['puppet_settings']['main']['logdir']
  $rundir = $facts['puppet_settings']['main']['rundir']
  $ssldir = $facts['puppet_settings']['main']['ssldir']
  $vardir = $facts['puppet_settings']['main']['vardir']
}
