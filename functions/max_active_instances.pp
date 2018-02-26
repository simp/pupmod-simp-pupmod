# Provides a reasonable calculation for the maximum number of active instances
# for a system
#
# Parameters are not to be used but are present as an assist to testing
#
# @param memory_limited_instances
# @param processor_count
#
# @return [Integer]
#   The maximum number of instances that should be active on the ``puppetserver``
#
function pupmod::max_active_instances (
  Integer[0] $memory_limited_instances = Integer(pick(fact('memorysize_mb'), 1) / 512),
  Integer[1] $processor_count          = pick(fact('processors.count'), 1)
){

  if ($memory_limited_instances < 2) or ($processor_count < 3) {
    $max_active_instances = 1
  }
  else {
    $max_active_instances = min($memory_limited_instances, $processor_count) - 1
  }

  $max_active_instances
}
