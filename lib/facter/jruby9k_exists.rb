#
# Return the discovered server version
#
Facter.add("jruby9k-exists") do
  confine {
    File.exist?('/opt/puppetlabs/bin/puppetserver') &&
    File.executable?('/opt/puppetlabs/bin/puppetserver')
  }

  setcode do
    File.exist?('/opt/puppetlabs/server/apps/puppetserver/jruby-9k.jar')
  end
end
