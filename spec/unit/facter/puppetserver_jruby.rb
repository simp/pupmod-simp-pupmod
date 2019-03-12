require "spec_helper"

#
#   This tests both the puppet_service_enabled and puppet_service_started facts.
#
describe 'custom fact puppetserver_jruby' do
  before (:each) do
     Facter.clear
  end

  context 'with installation directory existing' do

    it ' should return a hash' do
      File.expects(:directory?).with('/opt/puppetlabs/server/apps/puppetserver').returns(true)
      File.expects(:readable?).with('/opt/puppetlabs/server/apps/puppetserver').returns(true)
      Dir.expects(:glob).with('/opt/puppetlabs/server/apps/puppetserver/*.jar').returns(['/x/d/f/my.jar','/t/t/t/honey.jar'])

      expect(Facter.fact('puppetserver_jruby').value).to eq({
        'dir' => '/opt/puppetlabs/server/apps/puppetserver',
        'jarfiles' => ['my.jar','honey.jar']
      })
    end
  end
end

