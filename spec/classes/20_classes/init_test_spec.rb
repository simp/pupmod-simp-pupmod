require 'spec_helper'

describe 'pupmod' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      ['PC1', 'PE'].each do |distribution|
        context "with server_distribution = #{distribution}" do
          context 'with default parameters' do
            let(:params) { { server_distribution: distribution } }

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to have_pupmod__conf_resource_count(0) }
          end

          context 'with puppet_server set' do
            let(:params) { { server_distribution: distribution, puppet_server: '1.2.3.4' } }

            it { is_expected.to compile.with_all_deps }
          end
        end
      end
    end
  end
end
