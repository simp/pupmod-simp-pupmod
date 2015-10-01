require 'spec_helper'

describe 'pupmod::master::autosign' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) {facts}

      context 'base' do
        let(:title) { 'autosign_test' }
        let(:params) {{ :entry => 'foo bar' }}
        it { is_expected.to contain_concat_fragment("autosign+#{title}.autosign").with({
            :content => "#{title}\n#{params[:entry]}\n"
        })}
      end
    end
  end
end
