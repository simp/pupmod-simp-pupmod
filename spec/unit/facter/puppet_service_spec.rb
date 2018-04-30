require "spec_helper"

#
#   This tests both the puppet_service_enabled and puppet_service_started facts.
#
describe 'puppet_service_enabled', :type => :fact do
  before :each do
     Facter.clear
     Facter.clear_messages
  end

  context 'with systemd on linux' do
    before do
      Facter.fact(:kernel).stubs(:value).returns(:linux)
      Facter.add(:init_systems) { setcode { 'systemd' } }
    end

    context 'with puppet service on' do
      before(:each) do
        Facter::Core::Execution.stubs(:execute).with('/usr/bin/systemctl is-enabled puppet.service').returns 'enabled'
        Facter::Core::Execution.stubs(:execute).with('/usr/bin/systemctl status puppet.service').returns File.read('spec/files/systemctl_status_on.txt')
      end
      it 'should return true' do
        expect(Facter.fact(:puppet_service_enabled).value).to be true
        expect(Facter.fact(:puppet_service_started).value).to be true
      end
    end

    context 'with puppet service off' do
      before(:each) do
        Facter::Core::Execution.stubs(:execute).with('/usr/bin/systemctl is-enabled puppet.service').returns 'disabled'
        Facter::Core::Execution.stubs(:execute).with('/usr/bin/systemctl status puppet.service').returns File.read('spec/files/systemctl_status_off.txt')
      end
      it 'should return false' do
        expect(Facter.value(:puppet_service_enabled)).to be false
        expect(Facter.value(:puppet_service_started)).to be false
      end
    end
  end

  context 'without systemd on linux' do
    before do
      Facter.fact(:kernel).stubs(:value).returns(:linux)
      Facter.add(:init_systems) { setcode { 'sysv' } }
    end

    context 'with puppet service on' do
      before(:each) do
        Facter::Core::Execution.stubs(:execute).with('/sbin/chkconfig --list | grep -w puppet').returns 'puppet           0:off 1:off 2:off 3:on 4:on 5:on 6:off'
        Facter::Core::Execution.stubs(:execute).with('/sbin/service puppet status').returns 'puppet (pid  24188) is running...'
      end
      it 'should return true' do
        expect(Facter.value(:puppet_service_enabled)).to be true
        expect(Facter.value(:puppet_service_started)).to be true
      end
    end

    context 'with puppet service off' do
      before(:each) do
        Facter::Core::Execution.stubs(:execute).with('/sbin/chkconfig --list | grep -w puppet').returns 'puppet           0:off 1:off 2:off 3:off 4:off 5:off 6:off '
        Facter::Core::Execution.stubs(:execute).with('/sbin/service puppet status').returns 'this service is stopped'
      end
      it 'should return false' do
        expect(Facter.value(:puppet_service_enabled)).to be false
        expect(Facter.value(:puppet_service_started)).to be false
      end
    end
  end
end
