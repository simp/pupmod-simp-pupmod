require 'spec_helper'

describe 'pupmod::server_distribution' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      context 'with the puppet_settings fact' do
        let(:facts) do
          os_facts.merge(puppet_settings: { 'server' => { 'user' => 'puppet' } })
        end

        it { is_expected.to run.and_return('openvox-server') }
      end

      context 'with a PE server user' do
        let(:facts) do
          os_facts.merge(puppet_settings: { 'server' => { 'user' => 'pe-puppet' } })
        end

        it { is_expected.to run.and_return('PE') }
      end

      context 'without the puppet_settings fact' do
        let(:facts) do
          os_facts.reject { |k, _| k.to_s == 'puppet_settings' }
        end

        it { is_expected.to run.and_return('openvox-server') }
        it { is_expected.to run.with_params(false).and_return('openvox-server') }
      end
    end
  end
end
