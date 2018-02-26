require 'spec_helper'

describe 'pupmod::master::autosign' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) {facts}

      let(:title) { '*.foo.bar' }

      it { is_expected.to contain_concat__fragment("pupmod::master::autosign #{title}").with_content("#{title}\n") }

      context 'with different title' do
        let(:title) { 'autosign_test' }
        let(:params) {{ :entry => 'foo.bar' }}

        it { is_expected.to contain_concat__fragment("pupmod::master::autosign #{title}").with_content("# #{title}\n#{params[:entry]}\n") }
      end
    end
  end
end
