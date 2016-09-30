require 'spec_helper'

describe 'pupmod::master::base' do
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
        it { is_expected.to create_class('pupmod::master::base') }
        it { is_expected.to contain_user('puppet') }
        it { is_expected.to contain_group('puppet') }
      end
    end
  end
end
