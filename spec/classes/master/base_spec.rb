require 'spec_helper'

describe 'pupmod::master::base' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
      base_facts = {
        :processorcount => 4,
        :trusted        => { 'certname' => 'spec.test' },
      }
      let(:facts){ facts.merge(base_facts)}

      describe 'with default parameters' do
        it { is_expected.to create_class('pupmod::master::base') }
        it { is_expected.to contain_user('puppet') }
        it { is_expected.to contain_group('puppet') }
      end
    end
  end
end
