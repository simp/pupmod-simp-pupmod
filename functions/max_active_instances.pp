# Provides a reasonable calculation for the maximum number of active instances
# for a system
#
# Parameters are not to be used but are present as an assist to testing
#
# @param server_type
#
# @return [Integer]
#   The maximum number of JRuby instances that should be active on the ``puppetserver``
#
function pupmod::max_active_instances (
  Enum['monolithic', 'primary', 'compile'] $server_type = 'monolithic'
) {
  $processor_count = pick(fact('processors.count'), 1)

  # Figure out memory limited instances up front
  if $processor_count < 8 {
    $per_instance_mem = 512
  } elsif $processor_count < 16 {
    $per_instance_mem = 768
  } else {
    $per_instance_mem = 1024
  }

  $_floor_mem_instances = floor((($facts['memory']['system']['total_bytes'] / 1048576) * 0.8) / $per_instance_mem)
  $memory_limited_instances = $_floor_mem_instances ? {
    0       => 1,
    default => $_floor_mem_instances,
  }

  if $server_type == 'monolithic' {
    if $processor_count < 8 {
      $_ratio = (1.0 / 2)
    } elsif $processor_count < 16 {
      $_ratio = (5.0 / 8)
    } else {
      $_ratio = (11.0 / 16)
    }

    $cpu_limited_instances = max(floor($processor_count * $_ratio), 1)

    $max_active_instances = min($cpu_limited_instances, $memory_limited_instances)
  } elsif $server_type == 'primary' {
    # Calculations are simpler here
    if $processor_count < 4 {
      $max_active_instances = 1
    } elsif $processor_count < 16 {
      $max_active_instances = min(2, $memory_limited_instances)
    } else {
      $max_active_instances = min(4, $memory_limited_instances)
    }
  } else {
    # compile server
    $cpu_limited_instances = max($processor_count - 1, 1)

    $max_active_instances = min($cpu_limited_instances, $memory_limited_instances)
  }

  $max_active_instances
}
