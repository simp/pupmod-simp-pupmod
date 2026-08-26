require 'spec_helper_acceptance'

# Regression test for https://github.com/simp/pupmod-simp-pupmod/issues/186
#
# The puppet_agent.timer unit must carry an [Install] section; without one,
# `systemctl enable` exits 0 without creating the timers.target.wants symlink,
# so the timer never starts again after a reboot. `systemctl is-enabled` also
# exits 0 in that state (printing 'static'), so the assertions below check
# stdout strings, never exit codes.
describe 'puppet_agent timer reboot persistence' do
  # The earlier suite files enable SIMP's deny-by-default iptables, which
  # never opens port 22 — established beaker connections survive, but the
  # fresh SSH connection needed after the reboot below would be dropped.
  # Explicitly allow sshd so the post-reboot reconnect works.
  let(:manifest) do
    <<~EOS
      include 'pupmod'

      iptables::listen::tcp_stateful { 'allow_sshd':
        trusted_nets => ['ALL'],
        dports       => 22,
      }
    EOS
  end

  hosts.each do |host|
    context "on #{host}" do
      it 'applies the agent manifest' do
        apply_manifest_on(host, manifest, catch_failures: true)
      end

      it 'has an enabled (not static) puppet_agent.timer' do
        result = on(host, 'systemctl is-enabled puppet_agent.timer', accept_all_exit_codes: true)
        expect(result.stdout.strip).to eq('enabled')
      end

      it 'has the timer linked into timers.target.wants' do
        on(host, 'test -L /etc/systemd/system/timers.target.wants/puppet_agent.timer')
      end

      it 'has an active timer before reboot' do
        result = on(host, 'systemctl is-active puppet_agent.timer', accept_all_exit_codes: true)
        expect(result.stdout.strip).to eq('active')
      end

      it 'reboots the host' do
        skip 'Reboot is not supported under containers' if host[:hypervisor] == 'docker'
        host.reboot
      end

      it 'has an active timer after reboot' do
        skip 'Reboot is not supported under containers' if host[:hypervisor] == 'docker'
        result = on(host, 'systemctl is-active puppet_agent.timer', accept_all_exit_codes: true)
        expect(result.stdout.strip).to eq('active')
      end

      it 'still has an enabled timer after reboot' do
        skip 'Reboot is not supported under containers' if host[:hypervisor] == 'docker'
        result = on(host, 'systemctl is-enabled puppet_agent.timer', accept_all_exit_codes: true)
        expect(result.stdout.strip).to eq('enabled')
      end
    end
  end
end
