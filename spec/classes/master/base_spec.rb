require 'spec_helper'

describe 'pupmod::master::base' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do

      let(:facts) { os_facts.merge(
        { :puppet_settings => 
          { :main => 
            { 
              :confdir => '/etc/puppet',
              :environmentpath => '/etc/puppet/environments',
              :logdir => '/var/log/puppet',
              :rundir => '/var/run/puppet',
              :ssldir => '/var/lib/puppet/ssl',
              :vardir => '/var/lib/puppet'
            }
          }
        }) 
      }

      context 'with default parameters' do
        it { is_expected.to create_class('pupmod::master::base') }
        it { is_expected.to contain_user('puppet') }
        it { is_expected.to contain_group('puppet') }
      end
    end
  end
end
