require 'spec_helper'

describe 'pupmod::master::reports' do
  before :all do
    @extras = { :puppet_settings => {
      'master' => {
        'rest_authconfig' => '/etc/puppetlabs/puppet/authconf.conf'
    }}}
  end
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts){ @extras.merge(os_facts) }
      let(:pre_condition){ 'include "::pupmod::master"' }

      it { is_expected.to create_file('/etc/cron.daily/puppet_client_report_purge').with_content(/rm -f/) }
    end
  end
end
