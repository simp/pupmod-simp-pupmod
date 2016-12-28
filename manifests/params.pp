# A set of defaults for the 'pupmod' namespace
#
class pupmod::params {
  $puppet_config = {
    'classfile'       => '/opt/puppetlabs/puppet/cache/state/classes.txt',
    'confdir'         => '/etc/puppetlabs/puppet',
    'environmentpath' => '/etc/puppetlabs/code/environments',
    'logdir'          => '/var/log/puppetlabs/puppet',
    'rundir'          => '/var/run/puppetlabs',
    'ssldir'          => '/etc/puppetlabs/puppet/ssl',
    'vardir'          => '/opt/puppetlabs/puppet/cache'
  }
  $master_config = {
    'confdir' => '/etc/puppetlabs/puppetserver/conf.d',
    'codedir' => '/etc/puppetlabs/code',
    'vardir'  => '/opt/puppetlabs/server/data/puppetserver',
    'rundir'  => '/var/run/puppetlabs/puppetserver',
    'logdir'  => '/var/log/puppetlabs/puppetserver'
  }

  $master_install_dir = '/opt/puppetlabs/server/apps/puppetserver'
  $master_bootstrap_config = [
    '/etc/puppetlabs/puppetserver/services.d/',
    '/opt/puppetlabs/server/apps/puppetserver/config/services.d/'
    ]
}
