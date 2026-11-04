require 'spec_helper'

describe 'pupmod::master::autosign' do
  on_supported_os.to_a.values_at(0, -1).uniq.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:title) { '*.foo.bar' }

      it { is_expected.to compile.with_all_deps }
      it {
        is_expected.to contain_file_line('pupmod::master::autosign *.foo.bar').with(
          ensure: 'present',
          path: '/etc/puppetlabs/puppet/autosign.conf',
          line: '*.foo.bar',
        ).that_notifies('Class[pupmod::master::service]')
      }
      it { is_expected.not_to contain_file('/etc/puppetlabs/puppet/autosign.conf') }

      context 'with ensure => absent' do
        let(:params) { { ensure: 'absent' } }

        it { is_expected.to contain_file_line('pupmod::master::autosign *.foo.bar').with(ensure: 'absent', line: '*.foo.bar') }
      end

      context 'with a label and an entry' do
        let(:title) { 'autosign_test' }
        let(:params) { { entry: 'foo.bar' } }

        it { is_expected.to contain_file_line('pupmod::master::autosign autosign_test').with_line('foo.bar') }
      end

      context 'with an invalid name and no entry' do
        let(:title) { 'not a valid entry' }

        it { is_expected.to compile.and_raise_error(%r{'name' should be}) }
      end

      context 'with pupmod::puppet_group set' do
        let(:hieradata) { 'master_puppet_group' }

        it {
          is_expected.to contain_file('/etc/puppetlabs/puppet/autosign.conf').with(
            ensure: 'file',
            owner: 'root',
            group: 'puppet',
            mode: '0640',
          )
        }
      end
    end
  end
end
