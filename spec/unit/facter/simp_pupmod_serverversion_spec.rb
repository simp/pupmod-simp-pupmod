require 'spec_helper'

describe 'simp_pupmod_serverversion', type: :fact do
  let(:puppetserver) { '/opt/puppetlabs/bin/puppetserver' }

  before :each do
    Facter.clear
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:executable?).and_call_original
    allow(File).to receive(:exist?).with(puppetserver).and_return(true)
    allow(File).to receive(:executable?).with(puppetserver).and_return(true)
    allow(Facter::Core::Execution).to receive(:execute).and_call_original
  end

  it 'returns the server version' do
    allow(Facter::Core::Execution).to receive(:execute).with("#{puppetserver} --version", on_fail: nil).and_return("puppetserver version: 8.10.0\n")
    expect(Facter.fact(:simp_pupmod_serverversion).value).to eq('8.10.0')
  end

  it 'is nil when the version cannot be parsed' do
    allow(Facter::Core::Execution).to receive(:execute).with("#{puppetserver} --version", on_fail: nil).and_return("\n")
    expect(Facter.fact(:simp_pupmod_serverversion).value).to be_nil
  end

  it 'is not set without puppetserver' do
    allow(File).to receive(:exist?).with(puppetserver).and_return(false)
    expect(Facter::Core::Execution).not_to receive(:execute).with("#{puppetserver} --version", on_fail: nil)
    expect(Facter.value(:simp_pupmod_serverversion)).to be_nil
  end
end
