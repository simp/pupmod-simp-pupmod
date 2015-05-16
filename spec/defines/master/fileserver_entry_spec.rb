require 'spec_helper'

describe 'pupmod::master::fileserver_entry' do
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
  let(:title) { 'fileserver_entry_test' }

  context 'base' do

    let(:params) {{
      :path => '/good/path',
      :allow => ['foo.bar.baz']
    }}

    it do
      should contain_concat_fragment("fileserver+#{title}.fileserver").with({
        :content => "[#{title}]
 path #{params[:path]}
 allow #{params[:allow].first}

"
      })
    end
  end

  context 'bad_path' do
    let(:params) {{
      :path  => 'bad_path',
      :allow => ['foo.bar.baz']
    }}

    it do
      expect {
        should contain_concat_fragment("fileserver+#{title}.fileserver")
      }.to raise_error(Puppet::Error, /"#{params[:path]}" is not an absolute path/)
    end
  end

  context 'bad_allow' do
    let(:params) {{
      :path  => '/foo/bar',
      :allow => 'foo.bar.baz'
    }}

    it do
      expect {
        should contain_concat_fragment("fileserver+#{title}.fileserver")
      }.to raise_error(Puppet::Error, /"#{params[:allow]}" is not an Array/)
    end
  end
end
