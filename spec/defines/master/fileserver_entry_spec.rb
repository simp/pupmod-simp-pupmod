require 'spec_helper'

describe 'pupmod::master::fileserver_entry' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts
      end
      let(:title) { 'fileserver_entry_test' }

      context 'base' do
        let(:params) {{
          :path => '/good/path',
          :allow => ['foo.bar.baz']
        }}
        it { is_expected.to (
            contain_simpcat_fragment("fileserver+fileserver_entry_test.fileserver")
              .with_content(
                %r|\[fileserver_entry_test\]\n\s*path /good/path\n\sallow foo.bar.baz\n*|
        ))}
      end

      context 'bad_path' do
        let(:params) {{
          :path  => 'bad_path',
          :allow => ['foo.bar.baz']
        }}

        it do
          expect {
            is_expected.to contain_simpcat_fragment("fileserver+#{title}.fileserver")
          }.to raise_error(Puppet::Error, /parameter 'path' expects/)
        end
      end

      context 'bad_allow' do
        let(:params) {{
          :path  => '/foo/bar',
          :allow => 'foo.bar.baz'
        }}

        it do
          expect {
            is_expected.to contain_simpcat_fragment("fileserver+#{title}.fileserver")
          }.to raise_error(Puppet::Error)
        end
      end
    end
  end
end
