# Class: pupmod::master::base
#
# A break out of the mostly static files used by the Puppet master.
#
# == Authors
#
# * Trevor Vaughan <tvaughan@onyxpoint.com>
#
class pupmod::master::base {
  include '::pupmod::master'

  $masterport = $::pupmod::master::masterport

  $auto_fragdir = fragmentdir('autosign')
  concat_build { 'autosign':
    quiet  => true,
    order  => ['*.autosign'],
    target => "${::pupmod::confdir}/autosign.conf",
    notify => Exec['puppetserver_reload']
  }

  exec { 'puppetserver_reload':
    command     => '/usr/local/sbin/puppetserver_reload',
    refreshonly => true,
    require     => File['/usr/local/sbin/puppetserver_reload']
  }

  file { "${settings::ssldir}/ca/ca_crl.pem":
    audit  => 'content',
    notify => Service[$::pupmod::master::service]
  }

  file { $::pupmod::environmentpath:
    ensure => 'directory',
    owner  => 'root',
    group  => 'puppet',
    mode   => 'u=rwx,g=rwx,o-rwx',
    recurse => true,
    recurselimit => 1
  }

  file { "${::pupmod::confdir}/autosign.conf":
    owner     => 'root',
    group     => 'puppet',
    mode      => '0644',
    subscribe => Concat_build['autosign']
  }

  # Some simple helper scripts
  file { '/usr/local/sbin/puppetserver_clear_environment_cache':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '700',
    content => template('pupmod/usr/local/sbin/puppetserver_clear_environment_cache.erb')
  }

  file { '/usr/local/sbin/puppetserver_reload':
    ensure  => 'file',
    owner   => 'root',
    group   => 'root',
    mode    => '700',
    content => template('pupmod/usr/local/sbin/puppetserver_reload.erb')
  }

  puppet_auth { 'puppetlast_support':
    ensure     => 'present',
    path       => '^/node/([^/]+)$',
    path_regex => true,
    allow      => ['$1', $::fqdn],
    notify => Exec['puppetserver_reload']
  }

  group { 'puppet':
    ensure    => 'present',
    allowdupe => false,
    gid       => '52',
    tag       => 'firstrun',
    require   => Package[$::pupmod::master::service]
  }

  package { $::pupmod::master::service:
    ensure => 'latest',
    before => File[$::pupmod::confdir],
    notify => Service[$::pupmod::master::service]
  }

  service { $::pupmod::master::service:
    ensure     => 'running',
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
    home       => '/var/lib/puppet',
    membership => 'inclusive',
    shell      => '/sbin/nologin',
    tag        => 'firstrun',
    require    => Package['puppetserver']
  }
}
