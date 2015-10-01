require 'spec_helper'

describe 'pupmod' do
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
      let(:trusted_data){ trusted_facts } if Puppet.version >= "4.0.0"

      describe "with default parameters" do
        it { is_expected.to create_class('pupmod') }
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file('/etc/puppet/puppet.conf') }
        it {
          if facts[:operatingsystemmajrelease].to_i < 7
            is_expected.to contain_selboolean('puppet_manage_all_files')
          else
            is_expected.to contain_selboolean('puppetagent_manage_all_files')
          end
        }
        it { is_expected.not_to create_class('pupmod::master') }

        context 'with_selinux_disabled' do
          let(:base_facts) {{
              :selinux_current_mode => 'disabled',
              :selinux              => false,
          }}

          if os_facts[:operatingsystemmajrelease].to_i < 7 then
            it { is_expected.not_to contain_selboolean('puppet_manage_all_files') }
          else
            it { is_expected.not_to contain_selboolean('puppetagent_manage_all_files') }
          end
        end

        context 'with_master_enabled' do
          let(:params) {{ :enable_puppet_master => true, }}

          it { is_expected.to create_class('pupmod::master') }
        end
      end
    end
  end
end
