# Provides a reasonable calculation for the reserved code cache value for JRuby
# for a system
#
# @param max_active_instances
#
# @return [Pupmod::Memory]
#   The maximum number of JRuby instances that should be active on the ``puppetserver``
#
function pupmod::java_max_memory (
  Integer[1] $max_active_instances = 1,
) {
  $processor_count = pick(fact('processors.count'), 1)
  if $processor_count < 8 {
    $per_instance_mem = 512
  } elsif $processor_count < 16 {
    $per_instance_mem = 768
  } else {
    $per_instance_mem = 1024
  }

  if floor(fact('memorysize_mb')) < 1024 {
    $java_max_memory = '50%'
  } else {
    $java_mem_mb = $max_active_instances * $per_instance_mem
    $java_max_memory = "${java_mem_mb}m"
  }

  $java_max_memory
}
