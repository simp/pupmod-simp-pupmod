require 'spec_helper'
require 'hocon'

describe 'custom fact puppetserver_webserver' do
  let(:webserver_conf) { '/etc/puppetlabs/puppetserver/conf.d/webserver.conf' }

  before(:each) do
    Facter.clear

    allow(File).to receive(:readable?).and_call_original
  end

  context 'with a readable webserver.conf' do
    before(:each) do
      allow(File).to receive(:readable?).with(webserver_conf).and_return(true)
      allow(Hocon).to receive(:load).with(webserver_conf).and_return(
        'webserver' => { 'ssl-host' => '0.0.0.0', 'ssl-port' => 8140 },
      )
    end

    it 'returns the webserver section' do
      expect(Facter.fact('puppetserver_webserver').value).to eq('ssl-host' => '0.0.0.0', 'ssl-port' => 8140)
    end
  end

  context 'with an unparsable webserver.conf' do
    before(:each) do
      allow(File).to receive(:readable?).with(webserver_conf).and_return(true)
      allow(Hocon).to receive(:load).with(webserver_conf).and_raise(Hocon::ConfigError::ConfigParseError.new(nil, 'bad', nil))
    end

    it 'returns nil' do
      expect(Facter.fact('puppetserver_webserver').value).to be_nil
    end
  end

  context 'without a readable webserver.conf' do
    before(:each) do
      allow(File).to receive(:readable?).with(webserver_conf).and_return(false)
    end

    it 'returns nil' do
      expect(Facter.fact('puppetserver_webserver').value).to be_nil
    end
  end
end
