require 'spec_helper'

describe 'pupmod::master' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:trusted_facts){{
          'certname' => 'spec.test'
        }}
        let(:base_facts) {{
            :selinux_current_mode => 'enabled',
            :selinux              => true,
        }}
        let(:facts){
          x = os_facts.merge(base_facts)
          x[:trusted] = trusted_facts if Puppet.version < "4.0.0"
          x
        }
        if Puppet.version >= "4.0.0"
          let(:trusted_data){ trusted_facts }
        end

      shared_examples_for "a fact set master" do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('apache') }
        it { is_expected.to create_class('pupmod') }
        it { is_expected.to create_class('pupmod::master') }
        it { is_expected.to create_class('pupmod::master::base') }
      end

      describe "with default parameters" do
        it_behaves_like "a fact set master"
      end
    end
  end
end
