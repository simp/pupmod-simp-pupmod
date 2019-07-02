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
# @param puppetserver_exe
#   Fully qualified path to the ``puppetserver`` executable
#
# @param trigger_on_puppet_update
#   Run ``puppet generate types`` on all environments if the ``puppet``
#   application is updated
#
# @param puppet_exe
#   Fully qualified path to the ``puppet`` executable
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
#   Trigger paths to apply when ``$trigger_on_new_environment`` is true.
#
#   WARNING: Do *not* watch a large number of paths here!
#   * New format is a hash of the paths that should be watched and the
#     corresponding incron flags to apply to each path.
#   * Deprecated format is a list of paths to watch. The incron flags to apply
#     are hardcoded to ['IN_MODIFY', 'IN_CREATE', 'IN_NO_LOOP'].
#   * Ruby ``Dir`` compatible path globs are supported
#   * Use pupmod::generate_types_munge() to substitute the string
#     ``PUPPET_ENVIRONMENTPATH`` with all known Puppet environment paths.
#     (See ``$trigger_paths``default below for a usage example).
#   * Default watches for the creation of new environments in all known
#     Puppet environment paths.  Previously, the default watched
#     not only for new environments, but for any new modules within
#     an existing environment and any type changes within any module
#     within any existing environment.  However, this proved to be a
#     performance issue for some sites with large numbers of environments.
#
# @param run_dir
#   The directory to use for saving state and metadata for the
#   ``simp_generate_types`` process
#
class pupmod::master::generate_types (
  Boolean                     $enable                         = true,
  Boolean                     $trigger_on_puppetserver_update = true,
  Stdlib::AbsolutePath        $puppetserver_exe               = '/opt/puppetlabs/server/apps/puppetserver/bin/puppetserver',
  Boolean                     $trigger_on_puppet_update       = true,
  Stdlib::AbsolutePath        $puppet_exe                     = '/opt/puppetlabs/puppet/bin/puppet',
  Boolean                     $trigger_on_new_environment     = true,
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
      require     => File[$run_dir, $_generate_types_path],
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

  incron::system_table { 'simp_generate_types':
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
