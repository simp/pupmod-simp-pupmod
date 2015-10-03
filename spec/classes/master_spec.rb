require 'spec_helper'

describe 'pupmod::master' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
      base_facts = {
        :trusted => { 'certname' => 'spec.test' },
      }
      let(:facts){ facts.merge(base_facts)}

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
