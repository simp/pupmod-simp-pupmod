require 'spec_helper'

describe 'pupmod::master' do
  before :all do
    @extras = { :puppet_settings => {
      'master' => {
        'rest_authconfig' => '/etc/puppetlabs/puppet/authconf.conf'
    }}}
  end
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts){ @extras.merge(os_facts) }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to create_class('pupmod') }
      it { is_expected.to create_class('pupmod::master') }
      it { is_expected.to create_class('pupmod::master::base') }
    end
  end
end
