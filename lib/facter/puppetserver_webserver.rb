# Return puppetserver's webserver.conf: its `path` and its `webserver`
# section
#
# pupmod uses it to tell whether the file configures a single server or named
# servers, so that it writes settings where puppetserver reads them.
#
# The file is looked for in the configuration puppetserver is started with
# (`CONFIG=` in /etc/sysconfig/puppetserver), falling back to the package's
# /etc/puppetlabs/puppetserver/conf.d.
#
Facter.add('puppetserver_webserver') do
  setcode do
    sysconfig = '/etc/sysconfig/puppetserver'
    candidates = []

    if File.readable?(sysconfig)
      config = File.readlines(sysconfig).grep(%r{^\s*CONFIG=}).last
      if config
        config.sub(%r{^\s*CONFIG=}, '').strip.delete('"\'').split(',').each do |entry|
          entry = entry.strip
          next if entry.empty?

          candidates << ((File.basename(entry) == 'webserver.conf') ? entry : File.join(entry, 'webserver.conf'))
        end
      end
    end

    candidates << '/etc/puppetlabs/puppetserver/conf.d/webserver.conf'

    path = candidates.find { |candidate| File.readable?(candidate) }

    if path
      require 'hocon'

      begin
        { 'path' => path, 'webserver' => Hocon.load(path)['webserver'] }
      rescue StandardError => e
        Facter.debug("puppetserver_webserver: could not read #{path}: #{e.message}")
        nil
      end
    end
  end
end
