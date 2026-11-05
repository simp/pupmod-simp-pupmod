# @summary A break out of the mostly static files used by the Puppet master.
#
# @param helper_scripts
#   Install the `/usr/local/sbin/puppetserver_reload` and
#   `/usr/local/sbin/puppetserver_clear_environment_cache` helper scripts.
#
#   This also runs `puppetserver_reload` whenever `pupmod::master::service`
#   is notified (for example by a configuration change) while puppetserver is
#   running.
#
class pupmod::master::base (
  Boolean $helper_scripts = false,
) {
  include 'pupmod::master'
  include 'pupmod::master::install'
  include 'pupmod::master::service'

  Class['pupmod::master::install'] ~> Class['pupmod::master::service']

  $_puppet_group = $pupmod::puppet_group

  if $helper_scripts {
    exec { 'puppetserver_reload':
      command     => '/usr/local/sbin/puppetserver_reload',
      onlyif      => "/usr/bin/systemctl is-active --quiet ${pupmod::master::service::service_name}",
      refreshonly => true,
      subscribe   => Class['pupmod::master::service'],
      require     => File['/usr/local/sbin/puppetserver_reload'],
    }

    # Some simple helper scripts
    file { '/usr/local/sbin/puppetserver_clear_environment_cache':
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      content => epp("${module_name}/usr/local/sbin/puppetserver_clear_environment_cache", {
          'masterport'           => $pupmod::master::_masterport,
          'admin_api_mountpoint' => pick($pupmod::master::admin_api_mountpoint, '/puppet-admin-api'),
        }
      ),
    }

    $_puppetserver_reload_cmd = @(END)
      #!/bin/sh
      PATH=/opt/puppetlabs/bin:$PATH

      puppetserver reload
      | END

    file { '/usr/local/sbin/puppetserver_reload':
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      content => $_puppetserver_reload_cmd,
    }
  }

  if $_puppet_group =~ NotUndef {
    $_environmentpath = $pupmod::master::environmentpath ? {
      Stdlib::AbsolutePath => $pupmod::master::environmentpath,
      default              => $pupmod::environmentpath,
    }

    file { $_environmentpath:
      ensure       => 'directory',
      owner        => 'root',
      group        => $_puppet_group,
      mode         => 'u=rwx,g=rwx,o-rwx',
      recurse      => true,
      recurselimit => 1,
    }

    user { 'puppet':
      ensure    => 'present',
      allowdupe => false,
      comment   => 'Puppet User',
      gid       => 'puppet',
      home      => $pupmod::master::vardir,
      shell     => '/sbin/nologin',
      tag       => 'firstrun',
      require   => Class['pupmod::master::install'],
    }
  }
}
