require 'spec_helper'

describe 'pupmod::master::reports' do
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
      let(:pre_condition){ 'include "::pupmod::master"' }

      it { is_expected.to create_file('/etc/cron.daily/puppet_client_report_purge').with_content(/rm -f/) }
    end
  end
end
