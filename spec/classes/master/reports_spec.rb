require 'spec_helper'

describe 'pupmod::master::reports' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:trusted_facts){{ 'certname' => 'spec.test' }}
      let(:base_facts) {{ }}
      let(:facts){
        x = os_facts.merge(base_facts)
        x[:trusted] = trusted_facts if Puppet.version < "4.0.0"
        x
      }
      let(:trusted_data){ trusted_facts } if Puppet.version >= "4.0.0"
      it { is_expected.to create_file('/etc/cron.daily/puppet_client_report_purge').with_content(/rm -f/) }
    end
  end
end
