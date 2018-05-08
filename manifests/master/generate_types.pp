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
# @param trigger_paths
#   The paths that should be watched
#
#   * Ruby ``Dir`` compatible path globs are supported
#   * The string ``PUPPET_ENVIRONMENTPATH`` will be subsituted with all known
#   * Puppet Environment Paths
#
class pupmod::master::generate_types (
  Boolean                     $enable                         = true,
  Boolean                     $trigger_on_puppetserver_update = true,
  Boolean                     $trigger_on_puppet_update       = true,
  Array[Stdlib::AbsolutePath] $trigger_paths                  = pupmod::generate_types_munge([
                                '/PUPPET_ENVIRONMENTPATH',
                                '/PUPPET_ENVIRONMENTPATH/*/modules/*/lib/puppet/type/*.rb'
                              ])
){

  $_generate_types_path = '/usr/local/sbin/simp_generate_types'

  if $enable {
    file { $_generate_types_path:
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      content => epp("${module_name}${_generate_types_path}.epp"),
      notify  => Exec['simp_generate_types']
    }

    exec { 'simp_generate_types':
      command     => "${_generate_types_path} -p all",
      logoutput   => true,
      refreshonly => true
    }

    incron::system_table { 'simp_generate_types':
      custom_content => epp(
        "${module_name}/simp_generate_types_incron_rules.epp",
        {
          'trigger_on_puppetserver_update' => $trigger_on_puppetserver_update,
          'trigger_on_puppet_update'       => $trigger_on_puppet_update,
          'trigger_paths'                  => $trigger_paths,
          'simp_generate_types'            => $_generate_types_path
        }
      )
    }
  }
  else {
    file { $_generate_types_path: ensure => 'absent' }
    incron::system_table { 'simp_generate_types': enable => $enable }
  }
}
