#
require 'spec_helper'

describe 'pupmod::master::sysconfig' do
  on_supported_os.each do |os, os_facts|
    before :all do
      @extras = { :puppet_settings => {
        'master' => {
          'rest_authconfig' => '/etc/puppetlabs/puppet/authconf.conf'
      }}}
    end
    context "on #{os}" do

      let(:facts){ @extras.merge(os_facts) }

      context 'with default parameters' do
          puppetserver_content = File.open("#{File.dirname(__FILE__)}/data/puppetserver.txt", "rb").read;
          it { is_expected.to contain_file('/etc/sysconfig/puppetserver').with(
            {
              'owner' => 'root',
              'group' => 'puppet',
              'mode' => '0640',
            }
          )
          }
          it { is_expected.to contain_file('/etc/sysconfig/puppetserver').with_content(puppetserver_content) }
        it { is_expected.to create_class('pupmod::master::sysconfig') }
        it { is_expected.to contain_file('/opt/puppetlabs/puppet/cache/pserver_tmp').with(
            {
              'owner' => 'puppet',
              'group' => 'puppet',
              'ensure' => 'directory',
              'mode' => '0750'
            }
          )
        }
      end
    end
  end
end
