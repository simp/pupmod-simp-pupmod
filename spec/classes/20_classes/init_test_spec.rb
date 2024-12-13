require 'spec_helper'

File.open("#{File.dirname(__FILE__)}/data/auditd.txt", 'rb').read

describe 'pupmod' do
  on_supported_os.each do |os, os_facts|
    before :all do
      @extras = { puppet_settings: {
        'master' => {
          'rest_authconfig' => '/etc/puppetlabs/puppet/authconf.conf'
        }
      } }
    end
    context "on #{os}" do
      let(:facts) { @extras.merge(os_facts) }

      [
        'PC1',
        'PE',
      ].each do |distribution|
        context "with server_distribution = #{distribution}" do
          let(:params) { { server_distribution: distribution, puppet_server: '1.2.3.4' } }

          describe 'with default parameters' do
            it { is_expected.to compile.with_all_deps }
          end
        end
      end
    end
  end
end
