# @summary Use ``systemd`` to run ``puppet generate types`` when the necessary files have been changed
#
# NOTE: ``incron`` support has been removed due to continuing issues with ``incrond``.
# If you are using a system that does not support ``systemd``, you will need to
# run ``simp_generate_types`` using an alternate method (such as an ``r10k``
# post script).
#
# @param enable
#   Enable or disable automatic generation of types using ``puppet generate types``
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
#   created
#
# @param trigger_on_type_change
#
#   Watch all type files for changes and generate types when types are updated
#
# @param timeout
#   Seconds before the simp_generate_types script will kill any other
#   simp_generate_types processes and continue
#
# @param stability_timeout
#   Seconds before the simp_generate_types script will exit, without
#   processing, due to environments continuing to be created in the environment
#   path while the simp_generate_types script is attempting to execute
#
#   * This comes into play when deploying large numbers of environments and
#     generally should not need to be changed otherwise. If you see an error
#     message relating to environments not reaching stability, then you will
#     need to increase this number.
#
# @param run_dir
#   The directory to use for saving state and metadata for the
#   ``simp_generate_types`` process
#
class pupmod::master::generate_types (
  Boolean              $enable                         = true,
  Boolean              $trigger_on_puppetserver_update = true,
  Stdlib::AbsolutePath $puppetserver_exe               = '/opt/puppetlabs/server/apps/puppetserver/bin/puppetserver',
  Boolean              $trigger_on_puppet_update       = true,
  Stdlib::AbsolutePath $puppet_exe                     = '/opt/puppetlabs/puppet/bin/puppet',
  Boolean              $trigger_on_new_environment     = true,
  Boolean              $trigger_on_type_change         = true,
  Integer[0]           $timeout                        = 300,
  Integer[0]           $stability_timeout              = 500,
  Stdlib::AbsolutePath $run_dir                        = '/var/run/simp_generate_types'
){

  $_generate_types_path = '/usr/local/sbin/simp_generate_types'
  $_generate_types_command = "${_generate_types_path} --syslog --all --batch --timeout ${timeout} --stability_timeout ${stability_timeout}"

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
      command     => $_generate_types_command,
      refreshonly => true,
      require     => File[$run_dir],
      subscribe   => File[$_generate_types_path],
    }

    if 'systemd' in pick(fact('init_systems'), []) {
      simplib::assert_optional_dependency($module_name, 'camptocamp/systemd')

      systemd::unit_file { 'simp_generate_types.path':
        enable  => true,
        active  => true,
        content => epp("${module_name}/etc/systemd/system/simp_generate_types.path.epp")
      }

      $_simp_generate_types_service = @("HEREDOC")
        [Service]
        Type=simple
        ExecStart=${_generate_types_command}
        | HEREDOC

      systemd::unit_file { 'simp_generate_types.service':
        content => $_simp_generate_types_service
      }

      service { 'simp_generate_types':
        enable  => true,
        require => Systemd::Unit_file['simp_generate_types.service']
      }

      if $trigger_on_puppetserver_update or $trigger_on_puppet_update {
        systemd::unit_file { 'simp_generate_types_apps.path':
          enable  => true,
          active  => true,
          content => epp("${module_name}/etc/systemd/system/simp_generate_types.path.epp", { apps => true } )
        }

        $_simp_generate_types_force_service = @("HEREDOC")
          [Service]
          Type=simple
          ExecStart=${_generate_types_command} --force
          | HEREDOC

        systemd::unit_file { 'simp_generate_types_force.service':
          content => $_simp_generate_types_force_service
        }

        service { 'simp_generate_types_force':
          enable  => true,
          require => Systemd::Unit_file['simp_generate_types_force.service']
        }
      }
    }
    else {
      notify { 'simp_generate_types incron deprecated':
        message  => "simp_generate_types no longer supports incron due to continuing issues with the application. Please set ${module_name}::master::generate_types::enable to `false` for ${facts['fqdn']} to disable this message",
        loglevel => 'warning'
      }
    }
  }
  else {
    service { 'simp_generate_types': enable => false }
    service { 'simp_generate_types_force': enable => false }
    systemd::unit_file { 'simp_generate_types.path': ensure => absent }
    systemd::unit_file { 'simp_generate_types_apps.path': ensure =>  absent }
    systemd::unit_file { 'simp_generate_types.service': ensure => absent }
    systemd::unit_file { 'simp_generate_types_force.service': ensure => absent }
  }
}
