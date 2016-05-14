require 'spec_helper'

describe 'pupmod::master' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts){ facts }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to create_class('apache') }
      it { is_expected.to create_class('pupmod') }
      it { is_expected.to create_class('pupmod::master') }
      it { is_expected.to create_class('pupmod::master::base') }
    end
  end
end
