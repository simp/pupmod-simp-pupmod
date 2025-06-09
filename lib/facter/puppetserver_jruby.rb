# Return a list of jruby jar files in the installation directory
#
Facter.add('puppetserver_jruby') do
  confine do
    File.directory?('/opt/puppetlabs/server/apps/puppetserver') && File.readable?('/opt/puppetlabs/server/apps/puppetserver')
  end

  setcode do
    jruby_hash = {
      'dir' => '/opt/puppetlabs/server/apps/puppetserver',
      'jarfiles' => []
    }
    jarfiles = Dir.glob("#{jruby_hash['dir']}/*.jar")
    jruby_hash['jarfiles'] = jarfiles.map { |x| File.basename(x) }
    jruby_hash
  end
end
