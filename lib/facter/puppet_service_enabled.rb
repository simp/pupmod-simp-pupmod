#
# Determine if the puppet service is enabled.
#
Facter.add(:puppet_service_enabled) do
  confine kernel: 'linux'
  setcode do
    if Facter.value(:init_systems).include? 'systemd'
      Facter::Core::Execution.execute('/usr/bin/systemctl is-enabled puppet.service').include? 'enabled'
    else
      Facter::Core::Execution.execute('/sbin/chkconfig --list | grep -w puppet').include? ':on'
    end
  end
end
