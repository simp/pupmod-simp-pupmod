require 'spec_helper'

describe 'pupmod' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      context "with default parameters" do
        it { is_expected.to create_class('pupmod') }
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file('/etc/puppet/puppet.conf') }
        it 'operatingsystem < 7' do
          if facts[:operatingsystemmajrelease].to_i < 7
            is_expected.to contain_selboolean('puppet_manage_all_files')
          else
            is_expected.to contain_selboolean('puppetagent_manage_all_files')
          end
        end
        it { is_expected.not_to create_class('pupmod::master') }
        it { is_expected.to contain_class('haveged') }

        context 'with_selinux_disabled' do
          let(:facts) {
            facts[:selinux_current_mode] = 'disabled'
            facts[:selinux] = false

            facts
          }

          if facts[:operatingsystemmajrelease].to_i < 7 then
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

      context 'with use_haveged => false' do
        let(:params) {{:use_haveged => false}}
        it { is_expected.to_not contain_class('haveged') }
      end

      context 'with invalid input' do
        let(:params) {{:use_haveged => 'invalid_input'}}
        it 'with use_haveged as a string' do
          expect {
            is_expected.to compile
          }.to raise_error(RSpec::Expectations::ExpectationNotMetError,/invalid_input" is not a boolean/)
        end
      end

    end
  end
end
