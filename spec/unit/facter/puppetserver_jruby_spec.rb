require 'spec_helper'

#
#   This tests both the puppet_service_enabled and puppet_service_started facts.
#
describe 'custom fact puppetserver_jruby' do
  before(:each) do
    Facter.clear

    allow(File).to receive(:directory?).and_call_original
    allow(File).to receive(:readable?).and_call_original
    allow(Dir).to receive(:glob).and_call_original

    allow(File).to receive(:directory?).with('/opt/puppetlabs/server/apps/puppetserver').and_return(true)
    allow(File).to receive(:readable?).with('/opt/puppetlabs/server/apps/puppetserver').and_return(true)
    allow(Dir).to receive(:glob).with('/opt/puppetlabs/server/apps/puppetserver/*.jar').and_return(['/x/d/f/my.jar', '/t/t/t/honey.jar'])
  end

  context 'with installation directory existing' do
    it 'returns a hash' do
      expect(Facter.fact('puppetserver_jruby').value).to eq(
        'dir'      => '/opt/puppetlabs/server/apps/puppetserver',
        'jarfiles' => ['my.jar', 'honey.jar'],
      )
    end
  end
end
