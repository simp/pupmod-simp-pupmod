require 'spec_helper'
require 'hocon'

describe 'custom fact puppetserver_webserver' do
  let(:sysconfig) { '/etc/sysconfig/puppetserver' }
  let(:webserver_conf) { '/etc/puppetlabs/puppetserver/conf.d/webserver.conf' }
  let(:webserver) { { 'ssl-host' => '0.0.0.0', 'ssl-port' => 8140 } }

  before(:each) do
    Facter.clear

    allow(File).to receive(:readable?).and_call_original
    allow(File).to receive(:readable?).with(sysconfig).and_return(false)
  end

  context 'with a readable webserver.conf' do
    before(:each) do
      allow(File).to receive(:readable?).with(webserver_conf).and_return(true)
      allow(Hocon).to receive(:load).with(webserver_conf).and_return('webserver' => webserver)
    end

    it 'returns its path and webserver section' do
      expect(Facter.fact('puppetserver_webserver').value).to eq('path' => webserver_conf, 'webserver' => webserver)
    end
  end

  context 'with a conf.d set in the sysconfig file' do
    let(:custom_conf) { '/srv/puppetserver/conf.d/webserver.conf' }

    before(:each) do
      allow(File).to receive(:readable?).with(sysconfig).and_return(true)
      allow(File).to receive(:readlines).with(sysconfig).and_return(
        [
          "JAVA_BIN=\"/usr/bin/java\"\n",
          "CONFIG=\"/srv/puppetserver/conf.d\"\n",
        ],
      )
      allow(File).to receive(:readable?).with(custom_conf).and_return(true)
      allow(Hocon).to receive(:load).with(custom_conf).and_return('webserver' => webserver)
    end

    it 'reads webserver.conf from that directory' do
      expect(Facter.fact('puppetserver_webserver').value).to eq('path' => custom_conf, 'webserver' => webserver)
    end
  end

  context 'with a sysconfig CONFIG that has no webserver.conf' do
    before(:each) do
      allow(File).to receive(:readable?).with(sysconfig).and_return(true)
      allow(File).to receive(:readlines).with(sysconfig).and_return(["CONFIG=\"/srv/empty/conf.d\"\n"])
      allow(File).to receive(:readable?).with('/srv/empty/conf.d/webserver.conf').and_return(false)
      allow(File).to receive(:readable?).with(webserver_conf).and_return(true)
      allow(Hocon).to receive(:load).with(webserver_conf).and_return('webserver' => webserver)
    end

    it 'falls back to the package conf.d' do
      expect(Facter.fact('puppetserver_webserver').value).to eq('path' => webserver_conf, 'webserver' => webserver)
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
