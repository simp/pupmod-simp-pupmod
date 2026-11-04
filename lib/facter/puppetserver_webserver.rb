# Return the `webserver` section of puppetserver's webserver.conf
#
# pupmod uses it to tell whether the file configures a single server or named
# servers, so that it writes settings where puppetserver reads them.
#
Facter.add('puppetserver_webserver') do
  confine do
    File.readable?('/etc/puppetlabs/puppetserver/conf.d/webserver.conf')
  end

  setcode do
    require 'hocon'

    begin
      Hocon.load('/etc/puppetlabs/puppetserver/conf.d/webserver.conf')['webserver']
    rescue StandardError => e
      Facter.debug("puppetserver_webserver: could not read webserver.conf: #{e.message}")
      nil
    end
  end
end
