#
# Determine if the puppet service is started.
#
Facter.add(:puppet_service_started) do
  confine  :kernel => 'linux'
  setcode do
    if Facter.value(:service_provider) == 'systemd'
      Facter::Core::Execution.execute('/usr/bin/systemctl status puppet.service').include? "active (running)"
    else
      Facter::Core::Execution.execute('/sbin/service puppet status').include? "running"
    end
  end
end
