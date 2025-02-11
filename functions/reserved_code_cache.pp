# Provides a reasonable calculation for the reserved code cache value for JRuby
# for a system
#
# @return [Integer]
#   The maximum number of JRuby instances that should be active on the ``puppetserver``
#
function pupmod::reserved_code_cache {
  $mem_mb = Integer($facts['memory']['system']['total_bytes'] / 1048576)

  if $mem_mb < 8192 {
    $reserved_code_cache = 0
  } elsif $mem_mb < 16384 {
    $reserved_code_cache = 512
  } elsif $mem_mb < 32768 {
    $reserved_code_cache = 1024
  } else {
    $reserved_code_cache = 2048
  }

  $reserved_code_cache
}
