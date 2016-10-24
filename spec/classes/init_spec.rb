require 'spec_helper'

describe 'pupmod' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts.merge(
        { :puppet_settings => 
          { :main => 
            {
              :confdir => '/etc/puppet',
              :environmentpath => '/etc/puppet/environments',
              :logdir => '/var/log/puppet',
              :rundir => '/var/run/puppet',
              :ssldir => '/var/lib/puppet/ssl',
              :vardir => '/var/lib/puppet'
            }
          }
        }) 
      }

      describe "with default parameters" do
        it { is_expected.to create_class('pupmod') }
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('haveged') }
        it { is_expected.to contain_cron('puppet_crl_pull').with_command(
         %q{/usr/bin/curl -sS --cert /var/lib/puppet/ssl/certs/foo.example.com.pem --key /var/lib/puppet/ssl/private_keys/foo.example.com.pem -k -o /var/lib/puppet/ssl/crl.pem -H "Accept: s" https://1.2.3.4:8141/production/certificate_revocation_list/ca
}) }

        it { is_expected.to contain_cron('puppet_crl_pull').with_user('root') }
        it { is_expected.to contain_class('pupmod::agent::cron') }
        it { is_expected.to contain_pupmod__conf('agent_daemonize').with({
          'section' => ['agent'],
          'setting' => 'daemonize',
          'value' => 'false'
        }) }

        it { is_expected.to contain_pupmod__conf('server').with({
          'setting' => 'server',
          'value' => '1.2.3.4'
        }) }

        it { is_expected.to contain_pupmod__conf('ca_server').with({
          'setting' => 'ca_server',
          'value' => '$server'
        }) }

        it { is_expected.to contain_pupmod__conf('masterport').with({
          'setting' => 'masterport',
          'value' => '8140'
        }) }

        it { is_expected.to contain_pupmod__conf('report').with({
          'section' => ['agent'],
          'setting' => 'report',
          'value' => 'false'
        }) }

        it { is_expected.to contain_pupmod__conf('ca_port').with({
          'setting' => 'ca_port',
          'value' => '8141'
        }) }

        it { is_expected.to contain_pupmod__conf('splay').with({
          'setting' => 'splay',
          'value' => 'false'
        }) }

        it { is_expected.not_to contain_pupmod__conf('splaylimit') }
        it { is_expected.to contain_pupmod__conf('syslogfacility').with({
          'setting' => 'syslogfacility',
          'value' => 'local6'
        }) }

        it { is_expected.to contain_pupmod__conf('srv_domain').with({
          'setting' => 'srv_domain',
          'value' => 'example.com'
        }) }

        it { is_expected.to contain_pupmod__conf('certname').with({
          'setting' => 'certname',
          'value' => 'foo.example.com'
        }) }

        it { is_expected.to contain_pupmod__conf('classfile').with({
          'setting' => 'classfile',
          'value' => '$vardir/classes.txt'
        }) }

        it { is_expected.to contain_pupmod__conf('confdir').with({
          'setting' => 'confdir',
          'value' => '/etc/puppet'
        }) }

        it { is_expected.to contain_pupmod__conf('configtimeout').with({
          'setting' => 'configtimeout',
          'value' => '120'
        }) }

        it { is_expected.to contain_pupmod__conf('localconfig').with({
          'setting' => 'localconfig',
          'value' => '$vardir/localconfig'
        }) }

        it { is_expected.to contain_pupmod__conf('logdir').with({
          'setting' => 'logdir',
          'value' => '/var/log/puppet'
        }) }

        it { is_expected.to contain_pupmod__conf('rundir').with({
          'setting' => 'rundir',
          'value' => '/var/run/puppet'
        }) }

        it { is_expected.to contain_pupmod__conf('runinterval').with({
          'setting' => 'runinterval',
          'value' => '1800'
        }) }

        it { is_expected.to contain_pupmod__conf('ssldir').with({
          'setting' => 'ssldir',
          'value' => '/var/lib/puppet/ssl'
        }) }

        it { is_expected.to contain_pupmod__conf('stringify_facts').with({
          'setting' => 'stringify_facts',
          'value' => 'false'
        }) }

        it { is_expected.to contain_pupmod__conf('digest_algorithm').with({
          'setting' => 'digest_algorithm',
          'value' => 'sha256'
        }) }

        it { is_expected.not_to create_class('pupmod::master') }
        it { is_expected.to contain_class('auditd') }
        it { is_expected.to contain_auditd__add_rules('puppet_master').with_content( %q{
        -a always,exit -F dir=/etc/puppet -F uid!=puppet -p wa -k Puppet_Config
        -a always,exit -F dir=/var/log/puppet -F uid!=puppet -p wa -k Puppet_Log
        -a always,exit -F dir=/var/run/puppet -F uid!=puppet -p wa -k Puppet_Run
        -a always,exit -F dir=/var/lib/puppet/ssl -F uid!=puppet -p wa -k Puppet_SSL
      }) }

        it { is_expected.to contain_file('/etc/puppet').with({
          'ensure' => 'directory',
          'owner'  => 'root',
          'group'  => 'puppet',
          'mode'   => '0640'
        }) }

        it { is_expected.to contain_file('/etc/puppet/puppet.conf').with({
          'ensure' => 'file',
          'owner'  => 'root',
          'group'  => 'puppet',
          'mode'   => '0640',
          'audit'  => 'content'
        }) }

        it { is_expected.to contain_file('/etc/sysconfig/puppet').with({
          'ensure'  => 'file',
          'owner'   => 'root',
          'group'   => 'root',
          'mode'    => '0644',
          'content' => "PUPPET_EXTRA_OPTS='--daemonize'\n"
        }) }

        it { is_expected.to contain_package('puppet').with_ensure('latest') }
        it { is_expected.to contain_package('facter').with_ensure('latest') }
        it 'operatingsystem < 7' do
          if facts[:operatingsystemmajrelease].to_i < 7
            is_expected.to contain_selboolean('puppet_manage_all_files')
          else
            is_expected.to contain_selboolean('puppetagent_manage_all_files')
          end
        end

        context 'with_selinux_disabled' do
          let(:facts) { my_facts = os_facts.merge(
            { :puppet_settings => 
              { :main => 
                {
                  :confdir => '/etc/puppet',
                  :environmentpath => '/etc/puppet/environments',
                  :logdir => '/var/log/puppet',
                  :rundir => '/var/run/puppet',
                  :ssldir => '/var/lib/puppet/ssl',
                  :vardir => '/var/lib/puppet'
                }
              }
            }) 
            my_facts[:selinux_current_mode] = 'disabled'
            my_facts[:selinux] = false
            my_facts
          }

          if os_facts[:operatingsystemmajrelease].to_i < 7 then
            it { is_expected.not_to contain_selboolean('puppet_manage_all_files') }
          else
            it { is_expected.not_to contain_selboolean('puppetagent_manage_all_files') }
          end
        end
      end

      describe "with non-default parameters" do
        context 'with use_haveged => false' do
          let(:params) {{:use_haveged => false}}
          it { is_expected.to_not contain_class('haveged') }
        end

        context 'with daemonize enabled' do
          let(:params) {{:daemonize => true}}
          it { is_expected.to contain_cron('puppetagent').with_ensure('absent') }
          it { is_expected.to contain_service('puppet').with({
            'ensure'     => 'running',
            'enable'     => true,
            'hasrestart' => true,
            'hasstatus'  => false,
            'status'     => '/usr/bin/test `/bin/ps --no-headers -fC puppetd,"puppet agent" | /usr/bin/wc -l` -ge 1 -a ! `/bin/ps --no-headers -fC puppetd,"puppet agent" | /bin/grep -c "no-daemonize"` -ge 1',
            'subscribe'  => 'File[/etc/puppet/puppet.conf]'
          }) }
        end

        context 'with_master_enabled' do
          let(:params) {{ :enable_puppet_master => true, }}
          it { is_expected.to create_class('pupmod::master') }
        end

        context 'with auditd_support => false' do
          let(:params) {{:auditd_support => false}}
          it { is_expected.to_not contain_class('auditd') }
          it { is_expected.to_not contain_auditd__add_rules('puppet_master') }
        end

        context 'with non-empty splaylimit' do
          let(:params) {{:splaylimit => '5'}}
          it { is_expected.to contain_pupmod__conf('splaylimit').with({
            'setting' => 'splaylimit',
            'value' => '5'
          }) }
        end
      end

      describe 'with invalid input' do
        [:ssldir, :vardir].each do |path|
          context "with invalid #{path}" do
            let(:params) {{path => 'relative/path'}}
            it 'fails to compile' do
              expect { is_expected.to compile
              }.to raise_error(RSpec::Expectations::ExpectationNotMetError,%r{"relative/path" is not an absolute path})
            end
          end
        end

        context 'with invalid use_haveged' do
          let(:params) {{:use_haveged => 'invalid_input'}}
          it 'fails to compile' do
            expect {
              is_expected.to compile
            }.to raise_error(RSpec::Expectations::ExpectationNotMetError,/invalid_input" is not a boolean/)
          end
        end
      end
    end
  end
end
