require 'spec_helper'

describe 'pupmod::master::base' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:trusted_facts){{
          'certname' => 'spec.test'
        }}
        let(:base_facts) {{
          :processorcount => 4,
        }}
        let(:facts){
          x = os_facts.merge(base_facts)
          x[:trusted] = trusted_facts if Puppet.version < "4.0.0"
          x
        }
        if Puppet.version >= "4.0.0"
          let(:trusted_data){ trusted_facts }
        end

      describe 'with default parameters' do
        it { is_expected.to create_class('pupmod::master::base') }
        it { is_expected.to contain_user('puppet') }
        it { is_expected.to contain_group('puppet') }
      end
    end
  end
end
