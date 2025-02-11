# @summary A break out of the mostly static files used by the Puppet master.
#
class pupmod::master::base {
  include 'pupmod::master'
  include 'pupmod::master::install'
  include 'pupmod::master::service'

  Class['pupmod::master::install'] ~> Class['pupmod::master::service']

  # In Puppet 6.19 the section "master was renamed to "server" in Puppet.settings.
  # pick is used here to determine correct value for backwards compatability
  $_puppet_group = pick($facts.dig('puppet_settings','server','group'),$facts.dig('puppet_settings','master','group'))

  exec { 'puppetserver_reload':
    command     => '/usr/local/sbin/puppetserver_reload',
    refreshonly => true,
    subscribe   => Class['pupmod::master::service'],
    require     => File['/usr/local/sbin/puppetserver_reload'],
  }

  file { $pupmod::master::environmentpath:
    ensure       => 'directory',
    owner        => 'root',
    group        => $_puppet_group,
    mode         => 'u=rwx,g=rwx,o-rwx',
    recurse      => true,
    recurselimit => 1,
  }

  # Some simple helper scripts
  file { '/usr/local/sbin/puppetserver_clear_environment_cache':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    content => epp("${module_name}/usr/local/sbin/puppetserver_clear_environment_cache", {
      'masterport'           => $pupmod::master::masterport,
      'admin_api_mountpoint' => $pupmod::master::admin_api_mountpoint
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

  $auth_conf = '/etc/puppetlabs/puppetserver/conf.d/auth.conf'

  puppet_authorization { $auth_conf:
    version => 1,
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
