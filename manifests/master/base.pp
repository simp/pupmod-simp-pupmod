# A break out of the mostly static files used by the Puppet master.
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class pupmod::master::base {
  include '::pupmod::master'

  $masterport = $::pupmod::master::masterport
  $admin_api_mountpoint = $::pupmod::master::admin_api_mountpoint

  $auto_fragdir = simpcat_fragmentdir('autosign')
  simpcat_build { 'autosign':
    quiet  => true,
    order  => ['*.autosign'],
    target => "${::pupmod::confdir}/autosign.conf",
    notify => Service[$::pupmod::master::service]
  }

  exec { 'puppetserver_reload':
    command     => '/usr/local/sbin/puppetserver_reload',
    refreshonly => true,
    require     => File['/usr/local/sbin/puppetserver_reload']
  }

  file { "${::pupmod::ssldir}/ca/ca_crl.pem":
    audit  => 'content',
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

  file { "${::pupmod::master::confdir}/autosign.conf":
    owner     => 'root',
    group     => 'puppet',
    mode      => '0644',
    subscribe => Simpcat_build['autosign']
  }

  # Some simple helper scripts
  file { '/usr/local/sbin/puppetserver_clear_environment_cache':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    content => template('pupmod/usr/local/sbin/puppetserver_clear_environment_cache.erb')
  }

  file { '/usr/local/sbin/puppetserver_reload':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    content => template('pupmod/usr/local/sbin/puppetserver_reload.erb')
  }


  package { $::pupmod::master::service:
    ensure => 'latest',
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
