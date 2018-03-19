# A break out of the mostly static files used by the Puppet master.
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class pupmod::master::base {
  include '::pupmod::master'

  exec { 'puppetserver_reload':
    command     => '/usr/local/sbin/puppetserver_reload',
    refreshonly => true,
    require     => File['/usr/local/sbin/puppetserver_reload']
  }

  file { "${::pupmod::ssldir}/ca/ca_crl.pem":
    notify => Service[$::pupmod::master::service]
  }

  file { $::pupmod::master::environmentpath:
    ensure       => 'directory',
    owner        => 'root',
    group        => 'puppet',
    mode         => 'u=rwx,g=rwx,o-rwx',
    recurse      => true,
    recurselimit => 1
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
      })
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
    content => $_puppetserver_reload_cmd
  }

  package { $::pupmod::master::service:
    ensure => $::pupmod::master::package_ensure,
    before => File[$::pupmod::confdir],
    notify => Service[$::pupmod::master::service]
  }

  service { $::pupmod::master::service:
    ensure     => 'running',
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => [
      Package[$::pupmod::master::service],
      Group['puppet'],
      Class['pupmod::master::sysconfig']
    ]
  }

  user { 'puppet':
    ensure     => 'present',
    allowdupe  => false,
    comment    => 'Puppet User',
    uid        => '52',
    gid        => 'puppet',
    home       => $pupmod::master::vardir,
    membership => 'inclusive',
    shell      => '/sbin/nologin',
    tag        => 'firstrun',
    require    => Package['puppetserver']
  }
}
