require 'spec_helper'

#
#   This tests both the puppet_service_enabled and puppet_service_started facts.
#
describe 'puppet_service_enabled', type: :fact do
  before :each do
    Facter.clear
    Facter.clear_messages
  end

  context 'with systemd on linux' do
    before(:each) do
      allow(Facter.fact(:kernel)).to receive(:value).and_return(:linux)
      Facter.add(:init_systems) { setcode { 'systemd' } }
    end

    context 'with puppet service on' do
      before(:each) do
        allow(Facter::Core::Execution).to receive(:execute).with('/usr/bin/systemctl is-enabled puppet.service').and_return 'enabled'
        allow(Facter::Core::Execution).to receive(:execute).with('/usr/bin/systemctl status puppet.service').and_return File.read('spec/files/systemctl_status_on.txt')
      end
      it 'returns true' do
        expect(Facter.fact(:puppet_service_enabled).value).to be true
        expect(Facter.fact(:puppet_service_started).value).to be true
      end
    end

    context 'with puppet service off' do
      before(:each) do
        allow(Facter::Core::Execution).to receive(:execute).with('/usr/bin/systemctl is-enabled puppet.service').and_return 'disabled'
        allow(Facter::Core::Execution).to receive(:execute).with('/usr/bin/systemctl status puppet.service').and_return File.read('spec/files/systemctl_status_off.txt')
      end
      it 'returns false' do
        expect(Facter.value(:puppet_service_enabled)).to be false
        expect(Facter.value(:puppet_service_started)).to be false
      end
    end
  end

  context 'without systemd on linux' do
    before(:each) do
      allow(Facter.fact(:kernel)).to receive(:value).and_return(:linux)
      Facter.add(:init_systems) { setcode { 'sysv' } }
    end

    context 'with puppet service on' do
      before(:each) do
        allow(Facter::Core::Execution).to receive(:execute).with('/sbin/chkconfig --list | grep -w puppet').and_return 'puppet           0:off 1:off 2:off 3:on 4:on 5:on 6:off'
        allow(Facter::Core::Execution).to receive(:execute).with('/sbin/service puppet status').and_return 'puppet (pid  24188) is running...'
      end
      it 'returns true' do
        expect(Facter.value(:puppet_service_enabled)).to be true
        expect(Facter.value(:puppet_service_started)).to be true
      end
    end

    context 'with puppet service off' do
      before(:each) do
        allow(Facter::Core::Execution).to receive(:execute).with('/sbin/chkconfig --list | grep -w puppet').and_return 'puppet           0:off 1:off 2:off 3:off 4:off 5:off 6:off '
        allow(Facter::Core::Execution).to receive(:execute).with('/sbin/service puppet status').and_return 'this service is stopped'
      end
      it 'returns false' do
        expect(Facter.value(:puppet_service_enabled)).to be false
        expect(Facter.value(:puppet_service_started)).to be false
      end
    end
  end
end
