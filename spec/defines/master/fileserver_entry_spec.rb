require 'spec_helper'

describe 'pupmod::master::fileserver_entry' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:title) { 'fileserver_entry_test' }

      context 'puppetserver 4.0.0' do
        let(:facts) do
          os_facts.merge(
            simp_pupmod_serverversion: '4.0.0',
          )
        end

        let(:params) do
          {
            path: '/good/path',
            allow: ['foo.bar.baz'],
          }
        end

        it {
          is_expected.to(
            contain_concat_fragment("pupmod::master::fileserver_entry #{title}")
              .with_content(
                %r{\[fileserver_entry_test\]\n\s*path /good/path\n\sallow foo.bar.baz\n*},
              ),
          )
        }
      end

      context 'puppetserver 5.0.0' do
        let(:facts) do
          os_facts.merge(
            simp_pupmod_serverversion: '5.0.0',
          )
        end

        let(:params) do
          {
            path: '/good/path',
            allow: ['foo.bar.baz'],
          }
        end

        it {
          is_expected.to(
            contain_concat_fragment("pupmod::master::fileserver_entry #{title}")
              .with_content(
                %r{\[fileserver_entry_test\]\n\s*path /good/path},
              ),
          )
        }
      end
    end
  end
end
