# Use ``incrond`` to run ``puppet generate types`` when the necessary files
# have been changed
#
# @param enable
#   Enable ``puppet generate types`` management
#
# @param trigger_on_puppetserver_update
#   Run ``puppet generate types`` on all environments if the ``puppetserver``
#   application is updated
#
# @param trigger_on_puppet_update
#   Run ``puppet generate types`` on all environments if the ``puppet``
#   application is updated
#
# @param trigger_on_new_environment
#   Run ``puppet generate types`` on new environments as soon as they are
#   created.
#
#   WARNING: You should disable this option if you have over 100 environments
#   and expect to update them all simultaneously.
#
# @param delay
#   Wait this number of seconds prior to running ``puppet generate types``
#
#   * While not perfect, this can help alleviate race conditions with large
#     module deployments
#
# @param trigger_paths
#   The paths that should be watched
#
#   WARNING: Do *not* watch a large number of paths here!
#
#   * Ruby ``Dir`` compatible path globs are supported
#   * The string ``PUPPET_ENVIRONMENTPATH`` will be substituted with all known
#   * Puppet Environment Paths
#
# @param run_dir
#   The directory to use for saving state and metadata for the
#   ``simp_generate_types`` process
#
class pupmod::master::generate_types (
  Boolean                     $enable                         = false,
  Boolean                     $trigger_on_puppetserver_update = true,
  Stdlib::AbsolutePath        $puppetserver_exe               = '/opt/puppetlabs/server/apps/puppetserver/bin/puppetserver',
  Boolean                     $trigger_on_puppet_update       = true,
  Boolean                     $trigger_on_new_environment     = true,
  Stdlib::AbsolutePath        $puppet_exe                     = '/opt/puppetlabs/puppet/bin/puppet',
  Integer[0]                  $delay                          = 30,
  Variant[
    # For backward compatibility
    Array[Stdlib::AbsolutePath],
    Hash[Stdlib::AbsolutePath, Array[Incron::Mask]]
  ]                           $trigger_paths                  = pupmod::generate_types_munge({
    # Handles the creation of new environments
    '/PUPPET_ENVIRONMENTPATH'                             => ['IN_CREATE','IN_CLOSE_WRITE','IN_MOVED_TO','IN_ONLYDIR','IN_DONT_FOLLOW','recursive=false']
                                                                                      }),
  Stdlib::AbsolutePath        $run_dir                        = '/var/run/simp_generate_types'
){

  $_generate_types_path = '/usr/local/sbin/simp_generate_types'

  file { $_generate_types_path:
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => epp("${module_name}${_generate_types_path}.epp")
  }

  file { $run_dir:
    ensure => 'directory',
    owner  => 'root',
    group  => 'root',
    mode   => '0640'
  }

  if $enable {
    exec { 'simp_generate_types':
      command     => "${_generate_types_path} -d ${delay} -s -p all",
      refreshonly => true,
      subscribe   => File[$_generate_types_path],
      require     => File[$run_dir]
    }
  }

  if $trigger_on_puppetserver_update {
    incron::system_table { 'simp_generate_types_puppetserver_exe':
      enable         => $enable,
      custom_content => epp(
        "${module_name}/simp_generate_types_incron_rules/puppetserver.epp",
        {
          'simp_generate_types' => $_generate_types_path,
          'puppetserver_exe'    => $puppetserver_exe,
          'run_dir'             => $run_dir
        }
      ),
      require        => [
        File[$run_dir],
        File[$_generate_types_path]
      ]
    }
  }
  else {
    incron::system_table { 'simp_generate_types_puppetserver_exe': enable => false }
  }

  if $trigger_on_puppet_update {
    incron::system_table { 'simp_generate_types_puppet_exe':
      enable         => $enable,
      custom_content => epp(
        "${module_name}/simp_generate_types_incron_rules/puppet.epp",
        {
          'simp_generate_types' => $_generate_types_path,
          'puppet_exe'          => $puppet_exe,
          'run_dir'             => $run_dir
        }
      ),
      require        => [
        File[$run_dir],
        File[$_generate_types_path]
      ]
    }
  }
  else {
    incron::system_table { 'simp_generate_types_puppet_exe': enable => false }
  }

  if $trigger_on_new_environment {
    incron::system_table { 'simp_generate_types_new_environment':
      enable         => $enable,
      custom_content => epp(
        "${module_name}/simp_generate_types_incron_rules/new_environment.epp",
        {
          'simp_generate_types' => $_generate_types_path,
          'trigger_paths'       => $trigger_paths,
          'run_dir'             => $run_dir
        }
      ),
      require        => [
        File[$run_dir],
        File[$_generate_types_path]
      ]
    }
  }
  else {
    incron::system_table { 'simp_generate_types_new_environment': enable => false }
  }

  incron::system_table { 'simp_generate_types_update_trigger':
    enable         => $enable,
    custom_content => epp(
      "${module_name}/simp_generate_types_incron_rules/update_trigger.epp",
      {
        'simp_generate_types' => $_generate_types_path,
        'delay'               => $delay,
        'run_dir'             => $run_dir
      }
    ),
    require        => [
      File[$run_dir],
      File[$_generate_types_path]
    ]
  }
}
