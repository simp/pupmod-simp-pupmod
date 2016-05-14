require 'spec_helper'

describe 'pupmod::master::reports' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts){ facts }
      let(:pre_condition){ 'include "::pupmod::master"' }

      it { is_expected.to create_file('/etc/cron.daily/puppet_client_report_purge').with_content(/rm -f/) }
    end
  end
end
