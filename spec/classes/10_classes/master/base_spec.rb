require 'spec_helper'

describe 'pupmod::master::base' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_exec('puppetserver_reload') }
        it { is_expected.not_to contain_file('/usr/local/sbin/puppetserver_reload') }
        it { is_expected.not_to contain_file('/usr/local/sbin/puppetserver_clear_environment_cache') }
        it { is_expected.not_to contain_file('/etc/puppetlabs/code/environments') }
        it { is_expected.not_to contain_user('puppet') }
        it { is_expected.not_to contain_puppet_authorization('/etc/puppetlabs/puppetserver/conf.d/auth.conf') }
      end

      context 'with helper_scripts => true' do
        let(:params) { { helper_scripts: true } }

        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_exec('puppetserver_reload').with(
            command: '/usr/local/sbin/puppetserver_reload',
            onlyif: '/usr/bin/systemctl is-active --quiet puppetserver',
            refreshonly: true,
          ).that_subscribes_to('Class[pupmod::master::service]').that_requires('File[/usr/local/sbin/puppetserver_reload]')
        }
        it {
          is_expected.to contain_file('/usr/local/sbin/puppetserver_reload').with(
            ensure: 'file',
            owner: 'root',
            group: 'root',
            mode: '0700',
            content: %r{puppetserver reload},
          )
        }
        it {
          is_expected.to contain_file('/usr/local/sbin/puppetserver_clear_environment_cache').with(
            ensure: 'file',
            mode: '0700',
            content: %r{:8140/puppet-admin-api/v1/environment-cache},
          )
        }
      end

      context 'with helper_scripts and pupmod::master settings' do
        let(:hieradata) { 'master_base_helper_scripts' }

        it { is_expected.to contain_file('/usr/local/sbin/puppetserver_clear_environment_cache').with_content(%r{:8150/admin/v1/environment-cache}) }
      end

      context 'with pupmod::puppet_group set' do
        let(:hieradata) { 'master_puppet_group' }

        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_file('/etc/puppetlabs/code/environments').with(
            ensure: 'directory',
            owner: 'root',
            group: 'puppet',
            mode: 'u=rwx,g=rwx,o-rwx',
            recurse: true,
            recurselimit: 1,
          )
        }
        it {
          is_expected.to contain_user('puppet').with(
            ensure: 'present',
            gid: 'puppet',
            home: '/opt/puppetlabs/server/data/puppetserver',
            shell: '/sbin/nologin',
          ).that_requires('Class[pupmod::master::install]')
        }
      end
    end
  end
end
