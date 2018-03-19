#
# Return the discovered server version
#
Facter.add("simp_pupmod_serverversion") do
  confine {
    File.exist?('/opt/puppetlabs/bin/puppetserver') &&
    File.executable?('/opt/puppetlabs/bin/puppetserver')
  }

  setcode do
    version = Facter::Core::Execution.exec('/opt/puppetlabs/bin/puppetserver --version').strip.split(/\s+/)[-1]

    if version.nil? || (version.length <= 1)
      version = nil
    end

    version
  end
end
