require 'spec_helper'

describe 'pupmod::master::autosign' do
  base_facts = {
    :operatingsystem => 'RedHat',
    :lsbmajdistrelease => '6',
    :hardwaremodel => 'x86_64',
    :spec_title => description,
    :ipaddress => '1.2.3.4',
    :grub_version => '0.9',
    :uid_min => '500',
    :apache_version => '2.2',
    :init_systems => ['sysv','rc','upstart']
  }

  let(:facts) {base_facts}

  context 'base' do
    let(:title) { 'autosign_test' }

    let(:params) {{ :entry => 'foo bar' }}

    it do
      should contain_concat_fragment("autosign+#{title}.autosign").with({
        :content => "#{title}\n#{params[:entry]}\n"
      })
    end
  end
end
