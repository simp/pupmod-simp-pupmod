require 'spec_helper'

describe 'pupmod::master::fileserver_entry' do
  on_supported_os.to_a.values_at(0, -1).uniq.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:title) { 'fileserver_entry_test' }
      let(:params) { { path: '/good/path', allow: ['foo.bar.baz'] } }

      it { is_expected.to compile.with_all_deps }
      it {
        is_expected.to contain_ini_setting('pupmod::master::fileserver_entry fileserver_entry_test').with(
          ensure: 'present',
          path: '/etc/puppetlabs/puppet/fileserver.conf',
          section: 'fileserver_entry_test',
          setting: 'path',
          value: '/good/path',
          key_val_separator: ' ',
        ).that_notifies('Class[pupmod::master::service]')
      }
      it { is_expected.not_to contain_file('/etc/puppetlabs/puppet/fileserver.conf') }

      context 'with ensure => absent' do
        let(:params) { { path: '/good/path', allow: 'foo.bar.baz', ensure: 'absent' } }

        it { is_expected.to contain_ini_setting('pupmod::master::fileserver_entry fileserver_entry_test').with_ensure('absent') }
      end

      context 'with pupmod::puppet_group set' do
        let(:hieradata) { 'master_puppet_group' }

        it { is_expected.to contain_file('/etc/puppetlabs/puppet/fileserver.conf').with(ensure: 'file', group: 'puppet', mode: '0640') }
      end
    end
  end
end
