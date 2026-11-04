require 'spec_helper'

describe 'pupmod' do
  def mock_selinux_false_facts(os_facts)
    os_facts[:os][:selinux][:config_mode] = 'disabled'
    os_facts[:os][:selinux][:current_mode] = 'disabled'
    os_facts[:os][:selinux][:enabled] = false
    os_facts[:os][:selinux][:enforced] = false
    os_facts
  end

  def mock_selinux_enforcing_facts(os_facts)
    os_facts[:os][:selinux][:config_mode] = 'enforcing'
    os_facts[:os][:selinux][:config_policy] = 'targeted'
    os_facts[:os][:selinux][:current_mode] = 'enforcing'
    os_facts[:os][:selinux][:enabled] = true
    os_facts[:os][:selinux][:enforced] = true
    os_facts
  end

  # Facts that only exist once puppet or puppetserver is installed and running
  let(:post_install_facts) { [:puppet_service_enabled, :puppet_service_started, :puppetserver_jruby, :puppetserver_webserver] }

  on_supported_os.each do |os, os_facts|
    let(:node) { os_facts[:networking][:fqdn] } # sets trusted facts hash

    context "on #{os}" do
      let(:facts) { mock_selinux_enforcing_facts(Marshal.load(Marshal.dump(os_facts))) }

      # EL10 needs the package that provides the SELinux boolean
      let(:sebool_package_needed) { os_facts[:os][:release][:major].to_i >= 10 }

      context 'with a bare include' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('pupmod') }
        it { is_expected.to contain_package('openvox-agent').with_ensure('installed') }
        it { is_expected.not_to contain_class('haveged') }
        it { is_expected.not_to contain_class('pupmod::agent::cron') }
        it { is_expected.not_to contain_class('pupmod::facter::conf') }
        it { is_expected.not_to contain_class('pupmod::master') }
        it { is_expected.not_to contain_service('puppet') }
        it { is_expected.to have_pupmod__conf_resource_count(0) }
        it { is_expected.to have_ini_setting_resource_count(0) }
        it { is_expected.to have_file_line_resource_count(0) }
        it { is_expected.to have_file_resource_count(0) }
        it { is_expected.to have_group_resource_count(0) }
        it { is_expected.to have_exec_resource_count(0) }
        it { is_expected.to have_cron_resource_count(0) }
        it { is_expected.to have_systemd__timer_resource_count(0) }
        it { is_expected.to have_systemd__tmpfile_resource_count(0) }
        it { is_expected.to have_systemd__unit_file_resource_count(0) }
        it { is_expected.to have_package_resource_count(1) }
      end

      context 'with a bare include and no post-install facts (noop-safety)' do
        let(:facts) do
          mock_selinux_enforcing_facts(Marshal.load(Marshal.dump(os_facts))).reject { |k, _| post_install_facts.include?(k) }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to have_package_resource_count(1) }
      end

      context 'with enable_puppet_master => true and no post-install facts (noop-safety)' do
        let(:facts) do
          mock_selinux_enforcing_facts(Marshal.load(Marshal.dump(os_facts))).reject { |k, _| post_install_facts.include?(k) }
        end
        let(:params) { { enable_puppet_master: true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('pupmod::master') }
      end

      context 'with haveged => true' do
        let(:params) { { haveged: true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('haveged') }
      end

      context 'with agent_package and agent_package_install_options set' do
        let(:params) { { agent_package: 'puppet-agent', agent_package_install_options: ['--nogpgcheck'] } }

        it { is_expected.to contain_package('puppet-agent').with_install_options(['--nogpgcheck']) }
      end

      describe 'puppet.conf [main] settings' do
        {
          splay: [true, 'true'],
          runinterval: [900, '900'],
          digest_algorithm: ['md5', 'md5'],
          certname: ['foo.example.com', 'foo.example.com'],
          classfile: ['$vardir/classes.txt', '$vardir/classes.txt'],
          splaylimit: [300, '300'],
          syslogfacility: ['local5', 'local5'],
          srv_domain: ['example.org', 'example.org'],
        }.each do |param, (value, _)|
          context "with #{param} => #{value}" do
            let(:params) { { param => value } }

            it { is_expected.to compile.with_all_deps }
            it {
              is_expected.to contain_pupmod__conf(param.to_s).with(
                ensure: 'present',
                setting: param.to_s,
                value: value,
                confdir: '/etc/puppetlabs/puppet',
              )
            }
            it {
              is_expected.to contain_ini_setting("pupmod_#{param}").with(
                ensure: 'present',
                path: '/etc/puppetlabs/puppet/puppet.conf',
                section: 'main',
                setting: param.to_s,
              )
            }
          end

          context "with #{param} => 'absent'" do
            let(:params) { { param => 'absent' } }

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to contain_pupmod__conf(param.to_s).with_ensure('absent') }
            it { is_expected.to contain_ini_setting("pupmod_#{param}").with_ensure('absent') }
          end
        end

        context 'with a classfile that is not a path' do
          let(:params) { { classfile: 'classes.txt' } }

          it { is_expected.to compile.and_raise_error(%r{classfile}) }
        end

        context 'with main_settings' do
          let(:params) do
            {
              main_settings: {
                'vardir' => '/opt/puppetlabs/puppet/cache',
                'rundir' => 'absent',
                'splay'  => true,
              },
              splay: false,
            }
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_pupmod__conf('vardir').with(ensure: 'present', setting: 'vardir', value: '/opt/puppetlabs/puppet/cache') }
          it { is_expected.to contain_pupmod__conf('rundir').with(ensure: 'absent', setting: 'rundir') }
          it 'takes a setting from its named parameter over main_settings' do
            is_expected.to contain_pupmod__conf('splay').with(ensure: 'present', value: false)
          end
          it { is_expected.to have_pupmod__conf_resource_count(3) }
        end

        context 'with main_settings for a named parameter that is unset' do
          let(:params) { { main_settings: { 'splay' => true, 'runinterval' => 20 } } }

          it 'writes the setting from main_settings' do
            is_expected.to contain_pupmod__conf('splay').with(ensure: 'present', value: true)
            is_expected.to contain_pupmod__conf('runinterval').with(ensure: 'present', value: 20)
          end
        end
      end

      describe 'daemonize' do
        context 'with daemonize => false' do
          let(:params) { { daemonize: false } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_class('pupmod::agent::cron') }
          it {
            is_expected.to contain_service('puppet').with(
              ensure: 'stopped',
              enable: false,
              hasrestart: true,
              hasstatus: true,
            )
          }
          it { is_expected.to contain_pupmod__conf('agent_daemonize').with(section: 'agent', setting: 'daemonize', value: false) }
          it { is_expected.not_to contain_cron('puppetagent').with_ensure('present') }
        end

        context 'with daemonize => true' do
          let(:params) { { daemonize: true } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.not_to contain_class('pupmod::agent::cron') }
          it { is_expected.to contain_service('puppet').with(ensure: 'running', enable: true) }
          it { is_expected.to contain_pupmod__conf('agent_daemonize').with(section: 'agent', setting: 'daemonize', value: true) }
          it { is_expected.to contain_cron('puppetagent').with_ensure('absent') }
          it { is_expected.to contain_systemd__timer('puppet_agent.timer').with(ensure: 'absent', active: false, enable: false) }
          it { is_expected.to contain_systemd__unit_file('puppet_agent.service').with_ensure('absent').that_requires('Systemd::Timer[puppet_agent.timer]') }
          it { is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_ensure('absent') }
          it { is_expected.to contain_file('/usr/local/bin/careful_puppet_service_shutdown.sh').with_ensure('absent') }
        end
      end

      describe 'puppet.conf server settings (pass_two)' do
        context 'with puppet_server, ca_server, ca_port, masterport and report set' do
          let(:params) do
            {
              puppet_server: 'puppet.example.com',
              ca_server: '$server',
              ca_port: 8141,
              masterport: 8140,
              report: false,
            }
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_pupmod__conf('server').with(ensure: 'present', value: 'puppet.example.com') }
          it { is_expected.to contain_pupmod__conf('server_list').with_ensure('absent') }
          it { is_expected.to contain_pupmod__conf('ca_server').with(ensure: 'present', value: '$server') }
          it { is_expected.to contain_pupmod__conf('ca_port').with(ensure: 'present', value: 8141) }
          it { is_expected.to contain_pupmod__conf('masterport').with(ensure: 'present', value: 8140) }
          it { is_expected.to contain_pupmod__conf('report').with(ensure: 'present', section: 'agent', value: false) }
        end

        context 'with simp_options set in Hiera' do
          let(:hieradata) { 'agent_simp_options' }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_pupmod__conf('server').with(ensure: 'present', value: 'puppet.simp.test') }
          it { is_expected.to contain_pupmod__conf('ca_server').with(ensure: 'present', value: 'ca.simp.test') }
          it { is_expected.to contain_pupmod__conf('ca_port').with(ensure: 'present', value: 8141) }
          it { is_expected.not_to contain_pupmod__conf('masterport') }
          it { is_expected.not_to contain_pupmod__conf('report') }
        end

        context 'with puppet_group set' do
          let(:params) { { puppet_group: 'puppet' } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_group('puppet').with(ensure: 'present', allowdupe: false, tag: 'firstrun') }
          it { is_expected.to contain_file('/etc/puppetlabs/puppet').with(ensure: 'directory', owner: 'root', group: 'puppet', mode: '0640') }
          it { is_expected.to contain_file('/etc/puppetlabs/puppet/puppet.conf').with(ensure: 'file', owner: 'root', group: 'puppet', mode: '0640') }
        end
      end

      describe 'puppetagent_manage_all_files SELinux boolean' do
        context 'with puppetagent_manage_all_files => true' do
          let(:params) { { puppetagent_manage_all_files: true } }

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_exec('Set puppetagent_manage_all_files seboolean').with(
              command: '/usr/sbin/setsebool -P puppetagent_manage_all_files on',
              unless: "/usr/sbin/getsebool puppetagent_manage_all_files | /usr/bin/grep -q ' --> on'",
            )
          }
          it 'installs the package that provides the boolean only where the OS needs it' do
            if sebool_package_needed
              is_expected.to contain_package('selinux-policy-targeted-extra').with_ensure('installed')
              is_expected.to contain_exec('Refresh semodules after installing selinux-policy-targeted-extra')
                .that_requires('Package[selinux-policy-targeted-extra]')
                .that_comes_before('Exec[Set puppetagent_manage_all_files seboolean]')
            else
              is_expected.not_to contain_package('selinux-policy-targeted-extra')
              is_expected.not_to contain_exec('Refresh semodules after installing selinux-policy-targeted-extra')
            end
          end
        end

        context 'with puppetagent_manage_all_files => false' do
          let(:params) { { puppetagent_manage_all_files: false } }

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_exec('Set puppetagent_manage_all_files seboolean').with(
              command: '/usr/sbin/setsebool -P puppetagent_manage_all_files off',
              unless: "/usr/sbin/getsebool puppetagent_manage_all_files | /usr/bin/grep -q ' --> off'",
            )
          }
          it { is_expected.not_to contain_package('selinux-policy-targeted-extra') }
        end

        context 'with the deprecated manage_puppet_sebool => true' do
          let(:params) { { manage_puppet_sebool: true } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_exec('Set puppetagent_manage_all_files seboolean').with_command(%r{ on$}) }
        end

        context 'with the deprecated manage_puppet_sebool => false' do
          let(:params) { { manage_puppet_sebool: false } }

          it { is_expected.not_to contain_exec('Set puppetagent_manage_all_files seboolean') }
        end

        context 'with SELinux disabled' do
          let(:facts) { mock_selinux_false_facts(Marshal.load(Marshal.dump(os_facts))) }
          let(:params) { { puppetagent_manage_all_files: true } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.not_to contain_exec('Set puppetagent_manage_all_files seboolean') }
          it { is_expected.not_to contain_package('selinux-policy-targeted-extra') }
        end
      end

      describe 'puppet_extra_opts' do
        context 'with a value' do
          let(:params) { { puppet_extra_opts: '--daemonize' } }

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_file_line('pupmod PUPPET_EXTRA_OPTS').with(
              ensure: 'present',
              path: '/etc/sysconfig/puppet',
              line: "PUPPET_EXTRA_OPTS='--daemonize'",
              match: '^\s*PUPPET_EXTRA_OPTS=',
            ).that_requires('Class[pupmod::agent::install]')
          }
        end

        context "with 'absent'" do
          let(:params) { { puppet_extra_opts: 'absent' } }

          it {
            is_expected.to contain_file_line('pupmod PUPPET_EXTRA_OPTS').with(
              ensure: 'absent',
              match_for_absence: true,
            )
          }
        end
      end

      describe 'purge_logs' do
        context 'with purge_logs => true' do
          let(:params) { { purge_logs: true } }

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_systemd__tmpfile('puppet_purge_puppet_service_logs.conf').with(
              content: 'e /var/log/puppetlabs/puppet* - - - 4w',
            )
          }
        end

        context 'with purge_logs => true and no directories' do
          let(:params) { { purge_logs: true, purge_log_dirs: [] } }

          it { is_expected.to contain_systemd__tmpfile('puppet_purge_puppet_service_logs.conf').with_ensure('absent') }
        end

        context 'with purge_logs => true and a top-level logdir' do
          let(:params) { { purge_logs: true, logdir: '/puppet' } }

          it { is_expected.to compile.and_raise_error(%r{Refusing to purge top-level directories}) }
        end

        context 'with purge_logs => false' do
          let(:params) { { purge_logs: false } }

          it { is_expected.to contain_systemd__tmpfile('puppet_purge_puppet_service_logs.conf').with_ensure('absent') }
        end
      end

      context 'with set_environment => true' do
        let(:params) { { set_environment: true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_pupmod__conf('remove environment from main').with(ensure: 'absent', section: 'main', setting: 'environment') }
        it { is_expected.to contain_pupmod__conf('environment').with(section: 'agent', setting: 'environment', value: 'rp_env') }

        context 'running from bolt' do
          let(:environment) { 'bolt_catalog' }

          it { is_expected.not_to contain_pupmod__conf('environment') }
        end
      end

      context "with set_environment => 'no_clean'" do
        let(:params) { { set_environment: 'no_clean' } }

        it { is_expected.not_to contain_pupmod__conf('remove environment from main') }
        it { is_expected.to contain_pupmod__conf('environment') }
      end
    end
  end
end
