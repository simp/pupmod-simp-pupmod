require 'spec_helper'

# rubocop:disable RSpec/MultipleDescribes

# Custom facts that only exist once the packages are installed
POST_INSTALL_FACTS = [
  :puppetserver_webserver,
  :puppetserver_jruby,
  :puppet_service_enabled,
  :puppet_service_started,
  :simp_pupmod_serverversion,
].freeze

shared_examples_for 'a bare puppet server' do
  it { is_expected.to compile.with_all_deps }
  it { is_expected.to contain_package('openvox-server') }
  # openvox-agent and openvox-server, but not the release package
  it { is_expected.to have_package_resource_count(2) }
  it { is_expected.not_to contain_service('puppetserver') }
  it { is_expected.to have_hocon_setting_resource_count(0) }
  it { is_expected.to have_ini_setting_resource_count(0) }
  it { is_expected.to have_ini_subsetting_resource_count(0) }
  it { is_expected.to have_augeas_resource_count(0) }
  it { is_expected.to have_file_line_resource_count(0) }
  it { is_expected.to have_file_resource_count(0) }
  it { is_expected.to have_exec_resource_count(0) }
  it { is_expected.to have_user_resource_count(0) }
  it { is_expected.to have_group_resource_count(0) }
  it { is_expected.to have_systemd__unit_file_resource_count(0) }
  it { is_expected.to have_systemd__tmpfile_resource_count(0) }
  it { is_expected.to have_tidy_resource_count(0) }
  it { is_expected.to have_notify_resource_count(0) }
  it { is_expected.not_to contain_class('auditd') }
  it { is_expected.not_to contain_class('iptables') }
  it { is_expected.to have_pupmod__master__autosign_resource_count(0) }
end

describe 'pupmod::master' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it_behaves_like 'a bare puppet server'
      end

      context 'without the post-install custom facts' do
        let(:facts) { os_facts.reject { |k, _| POST_INSTALL_FACTS.include?(k.to_sym) } }

        it_behaves_like 'a bare puppet server'
      end
    end
  end

  on_supported_os.to_a.values_at(0, -1).uniq.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      describe 'puppet.conf settings' do
        {
          'master_environmentpath'   => ['server', 'environmentpath', :environmentpath, '/srv/environments'],
          'master_daemonize'         => ['server', 'daemonize', :daemonize, true],
          'master_masterport'        => ['server', 'masterport', :masterport, 8150],
          'master_ca_port'           => ['server', 'ca_port', :ca_port, 8141],
          'ca_ttl'                   => ['server', 'ca_ttl', :ca_ttl, '5y'],
          'keylength'                => ['server', 'keylength', :keylength, 2048],
          'freeze_main'              => ['main', 'freeze_main', :freeze_main, false],
          'strict_hostname_checking' => ['main', 'strict_hostname_checking', :strict_hostname_checking, true],
        }.each do |title, (section, setting, param, value)|
          context "with #{param} set" do
            let(:params) { { param => value } }

            it { is_expected.to compile.with_all_deps }
            it {
              is_expected.to contain_pupmod__conf(title).with(
                ensure: 'present',
                section: section,
                setting: setting,
                value: value,
                confdir: '/etc/puppetlabs/puppet',
              ).that_notifies('Class[pupmod::master::service]')
            }
            it {
              is_expected.to contain_ini_setting("pupmod_#{title}").with(
                ensure: 'present',
                path: '/etc/puppetlabs/puppet/puppet.conf',
                section: section,
                setting: setting,
                value: value,
              )
            }
          end

          context "with #{param} => 'absent'" do
            let(:params) { { param => 'absent' } }

            it { is_expected.to contain_ini_setting("pupmod_#{title}").with_ensure('absent') }
          end

          context "without #{param}" do
            it { is_expected.not_to contain_pupmod__conf(title) }
          end
        end
      end

      describe 'CVE-2020-7942 warning' do
        context 'with strict_hostname_checking => false' do
          let(:params) { { strict_hostname_checking: false } }

          it { is_expected.to contain_notify('CVE-2020-7942').with_message(%r{strict_hostname_checking' to 'false' enables CVE-2020-7942}) }
        end

        context 'with strict_hostname_checking => false and the warning off' do
          let(:params) { { strict_hostname_checking: false, cve_2020_7942_warning: false } }

          it { is_expected.not_to contain_notify('CVE-2020-7942') }
        end

        context 'with strict_hostname_checking => true' do
          let(:params) { { strict_hostname_checking: true } }

          it { is_expected.not_to contain_notify('CVE-2020-7942') }
        end
      end

      context 'with pupmod::puppet_group set' do
        let(:hieradata) { 'master_puppet_group' }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file('/etc/puppetlabs/puppetserver').with(ensure: 'directory', owner: 'root', group: 'puppet', mode: '0660') }
        it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d').with(ensure: 'directory', owner: 'root', group: 'puppet', mode: '0640') }
        it { is_expected.to contain_file('/etc/puppetlabs/code').with(ensure: 'directory', owner: 'root', group: 'puppet', mode: '0640') }
        it { is_expected.to contain_file('/var/run/puppetlabs/puppetserver').with(ensure: 'directory', owner: 'puppet', group: 'puppet').without_mode }
        it { is_expected.to contain_file('/etc/puppetlabs/puppet/ssl').with(ensure: 'directory', owner: 'puppet', group: 'puppet').without_mode }
        it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d').that_requires('Class[pupmod::master::install]') }
      end

      describe 'firewall' do
        context 'with simp_options::firewall' do
          let(:hieradata) { 'master_firewall' }

          it { is_expected.to contain_class('iptables') }
          it { is_expected.to contain_iptables__listen__tcp_stateful('allow_puppet').with(dports: 8140, trusted_nets: ['10.0.0.0/8']) }
          it { is_expected.not_to contain_iptables__listen__tcp_stateful('allow_puppetca') }
        end

        context 'with firewall, masterport and ca_port' do
          let(:params) { { firewall: true, masterport: 8150, ca_port: 8151 } }

          it { is_expected.to contain_iptables__listen__tcp_stateful('allow_puppet').with_dports(8150) }
          it { is_expected.to contain_iptables__listen__tcp_stateful('allow_puppetca').with_dports(8151) }
        end

        context 'with firewall, ca_port and enable_ca => false' do
          let(:params) { { firewall: true, ca_port: 8141, enable_ca: false } }

          it { is_expected.not_to contain_iptables__listen__tcp_stateful('allow_puppetca') }
        end

        context 'with firewall and enable_master => false' do
          let(:params) { { firewall: true, ca_port: 8141, enable_master: false } }

          it { is_expected.not_to contain_iptables__listen__tcp_stateful('allow_puppet') }
          it { is_expected.to contain_iptables__listen__tcp_stateful('allow_puppetca').with_dports(8141) }
        end
      end

      describe 'auditd' do
        context 'with simp_options::auditd' do
          let(:hieradata) { 'master_auditd' }

          it { is_expected.to contain_class('auditd') }
          it { is_expected.to contain_auditd__rule('puppet_master').with_content(%r{dir=/etc/puppetlabs/puppetserver/conf.d -F uid!=puppet}) }
        end

        context 'with auditd => true' do
          let(:params) { { auditd: true } }

          it { is_expected.to contain_auditd__rule('puppet_master') }
        end
      end

      describe 'autosign' do
        context 'with autosign_entries' do
          let(:params) do
            {
              autosign_entries: {
                '*.foo.bar' => {},
                'old.foo.bar' => { 'ensure' => 'absent' },
              },
            }
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_pupmod__master__autosign('*.foo.bar').with_ensure('present') }
          it { is_expected.to contain_pupmod__master__autosign('old.foo.bar').with_ensure('absent') }
          it { is_expected.to contain_file_line('pupmod::master::autosign *.foo.bar').with(ensure: 'present', line: '*.foo.bar', path: '/etc/puppetlabs/puppet/autosign.conf') }
        end

        context 'with the deprecated autosign_hosts' do
          let(:params) do
            {
              autosign_hosts: ['*.legacy.bar', 'both.bar'],
              autosign_entries: { 'both.bar' => { 'ensure' => 'absent' } },
            }
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_pupmod__master__autosign('*.legacy.bar').with_ensure('present') }
          # The deprecated Array is applied last
          it { is_expected.to contain_pupmod__master__autosign('both.bar').with_ensure('present') }
        end
      end
    end
  end
end

describe 'pupmod' do
  on_supported_os.each do |os, os_facts|
    context "on #{os} with enable_puppet_master" do
      let(:facts) { os_facts }
      let(:params) { { enable_puppet_master: true } }

      it_behaves_like 'a bare puppet server'
      it { is_expected.to contain_class('pupmod::master') }
    end
  end
end

describe 'pupmod::master::service' do
  on_supported_os.to_a.values_at(0, -1).uniq.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.not_to contain_service('puppetserver') }
      end

      context 'with service_ensure and service_enable' do
        let(:params) { { service_ensure: 'running', service_enable: true } }

        it { is_expected.to contain_service('puppetserver').with(ensure: 'running', enable: true, hasrestart: true, hasstatus: true) }
      end

      context 'with only service_enable' do
        let(:params) { { service_enable: false } }

        it { is_expected.to contain_service('puppetserver').with_enable(false).without_ensure }
      end

      context 'with only service_ensure' do
        let(:params) { { service_ensure: 'stopped' } }

        it { is_expected.to contain_service('puppetserver').with_ensure('stopped').without_enable }
      end

      context 'on PE' do
        let(:facts) { os_facts.merge(pe_build: '2019.8.0') }
        let(:params) { { service_ensure: 'running', service_enable: true } }

        it { is_expected.to have_service_resource_count(0) }
      end
    end
  end
end

describe 'pupmod::master' do
  on_supported_os.to_a.values_at(0, -1).uniq.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with the service managed in Hiera' do
        let(:hieradata) { 'master_service_managed' }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_service('puppetserver').with(ensure: 'running', enable: true) }
        it { is_expected.to contain_class('pupmod::master::install').that_notifies('Class[pupmod::master::service]') }
        it { is_expected.to contain_class('pupmod::master::config').that_notifies('Class[pupmod::master::service]') }
        it { is_expected.to contain_class('pupmod::master::sysconfig').that_notifies('Class[pupmod::master::service]') }
      end

      describe 'pupmod::master::install' do
        context 'with install_release_package' do
          let(:hieradata) { 'master_install_release_package' }
          let(:release) { "https://yum.voxpupuli.org/openvox8-release-el-#{os_facts.dig(:os, :release, :major) || os_facts.dig(:os, 'release', 'major')}.noarch.rpm" }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_package(release) }
          it { is_expected.to contain_package('openvox-server').that_requires("Package[#{release}]") }
        end

        context 'with pupmod::openvox_rpm_path' do
          let(:hieradata) { 'master_install_rpm_path' }

          it { is_expected.to contain_package('openvox-server').with_source('/tmp/openvox-server.rpm') }
          it { is_expected.to have_package_resource_count(2) }
        end
      end
    end
  end
end
# rubocop:enable RSpec/MultipleDescribes
