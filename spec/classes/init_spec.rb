#
require 'spec_helper'

describe 'pupmod' do
  on_supported_os.each do |os, os_facts|
    before :all do
      @extras = { :puppet_settings => {
        'master' => {
          'rest_authconfig' => '/etc/puppetlabs/puppet/authconf.conf'
        }}}
    end
      context "on #{os}" do
        let(:facts){ @extras.merge(os_facts) }

        describe "with default parameters" do
          it { is_expected.to create_class('pupmod') }
          it { is_expected.to compile.with_all_deps }
          it { is_expected.not_to contain_class('haveged') }
          it { is_expected.to contain_package('puppet-agent').with_ensure('latest') }
          it { is_expected.to contain_file('/etc/puppetlabs/puppet').with({
            'ensure' => 'directory',
            'owner'  => 'root',
            'group'  => 'root',
            'mode'   => '0640'
          }) }

          it { is_expected.to contain_file('/etc/puppetlabs/puppet/puppet.conf').with({
            'ensure' => 'file',
            'owner'  => 'root',
            'group'  => 'root',
            'mode'   => '0640',
            'audit'  => 'content'
          }) }

          it { is_expected.to contain_cron('puppet_crl_pull').with_command(
            "/usr/bin/curl -sS --cert /etc/puppetlabs/puppet/ssl/certs/foo.example.com.pem --key /etc/puppetlabs/puppet/ssl/private_keys/foo.example.com.pem -k -o /etc/puppetlabs/puppet/ssl/crl.pem -H \"Accept: s\" https://1.2.3.4:8141/puppet-ca/v1/certificate_revocation_list/ca\n") }

          it { is_expected.to contain_cron('puppet_crl_pull').with_user('root') }
          it { is_expected.to contain_class('pupmod::agent::cron') }
          it { is_expected.to contain_pupmod__conf('agent_daemonize').with({
            'section' => 'agent',
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
            'value' => 8140
          }) }

          it { is_expected.to contain_pupmod__conf('report').with({
            'section' => 'agent',
            'setting' => 'report',
            'value' => false
          }) }

          it { is_expected.to contain_pupmod__conf('ca_port').with({
            'setting' => 'ca_port',
            'value' => 8141
          }) }

          it { is_expected.to contain_pupmod__conf('splay').with({
            'setting' => 'splay',
            'value' => false
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

          it { is_expected.to contain_pupmod__conf('vardir').with({
            'setting' => 'vardir',
            'value' => '/opt/puppetlabs/puppet/cache',
          }) }

          it { is_expected.to contain_pupmod__conf('classfile').with({
            'setting' => 'classfile',
             'value' => '$vardir/classes.txt'
          }) }

          it { is_expected.to contain_pupmod__conf('confdir').with({
            'setting' => 'confdir',
            'value' => '/etc/puppetlabs/puppet'
          }) }

          it { is_expected.to contain_pupmod__conf('logdir').with({
            'setting' => 'logdir',
            'value' => '/var/log/puppetlabs/puppet'
          }) }

          it { is_expected.to contain_pupmod__conf('rundir').with({
            'setting' => 'rundir',
            'value' => '/var/run/puppetlabs'
          }) }

          it { is_expected.to contain_pupmod__conf('runinterval').with({
            'setting' => 'runinterval',
            'value' => 1800
          }) }

          it { is_expected.to contain_pupmod__conf('ssldir').with({
            'setting' => 'ssldir',
            'value' => '/etc/puppetlabs/puppet/ssl'
          }) }

          it { is_expected.to contain_pupmod__conf('stringify_facts').with({
            'setting' => 'stringify_facts',
            'value' => false
          }) }

          it { is_expected.to contain_pupmod__conf('digest_algorithm').with({
            'setting' => 'digest_algorithm',
            'value' => 'sha256'
          }) }
          it { is_expected.to contain_ini_setting("pupmod_agent_daemonize") }

          it { is_expected.to contain_ini_setting("pupmod_server") }

          it { is_expected.to contain_ini_setting("pupmod_ca_server") }

          it { is_expected.to contain_ini_setting("pupmod_masterport") }

          it { is_expected.to contain_ini_setting("pupmod_report") }

          it { is_expected.to contain_ini_setting("pupmod_ca_port") }

          it { is_expected.to contain_ini_setting("pupmod_splay") }

          it { is_expected.to contain_ini_setting("pupmod_syslogfacility") }

          it { is_expected.to contain_ini_setting("pupmod_srv_domain") }

          it { is_expected.to contain_ini_setting("pupmod_certname") }

          it { is_expected.to contain_ini_setting("pupmod_vardir") }

          it { is_expected.to contain_ini_setting("pupmod_classfile") }

          it { is_expected.to contain_ini_setting("pupmod_confdir") }

          it { is_expected.to contain_ini_setting("pupmod_logdir") }

          it { is_expected.to contain_ini_setting("pupmod_rundir") }

          it { is_expected.to contain_ini_setting("pupmod_runinterval") }

          it { is_expected.to contain_ini_setting("pupmod_ssldir") }

          it { is_expected.to contain_ini_setting("pupmod_stringify_facts") }

          it { is_expected.to contain_ini_setting("pupmod_digest_algorithm") }

          it { is_expected.to contain_class('auditd') }
          audit_content = File.open("#{File.dirname(__FILE__)}/data/auditd.txt", "rb").read;

          it { is_expected.to contain_auditd__add_rules('puppet_master').with_content(audit_content)}

          it { is_expected.to contain_file('/etc/sysconfig/puppet').with({
            'ensure'  => 'file',
            'owner'   => 'root',
            'group'   => 'root',
            'mode'    => '0644',
            'content' => "PUPPET_EXTRA_OPTS='--daemonize'\n"
          }) }
          it 'operatingsystem < 7' do
            if os_facts[:operatingsystemmajrelease].to_i < 7
              is_expected.to contain_selboolean('puppet_manage_all_files')
            else
              is_expected.to contain_selboolean('puppetagent_manage_all_files')
            end
          end

          context 'with_selinux_disabled' do
            let(:facts) {
              _facts = @extras.merge(os_facts)
              _facts[:selinux_current_mode] = 'disabled'
              _facts[:selinux] = false

              _facts
            }

            if os_facts[:operatingsystemmajrelease].to_i < 7 then
              it { is_expected.not_to contain_selboolean('puppet_manage_all_files') }
            else
              it { is_expected.not_to contain_selboolean('puppetagent_manage_all_files') }
            end
          end
        end

        describe "with non-default parameters" do
          context 'with haveged => true' do
            let(:params) {{ :haveged => true }}
            it { is_expected.to contain_class('haveged') }
          end

          context 'with enable_puppet_master => false' do
            let(:params) {{ :enable_puppet_master => true, }}
            it { is_expected.to create_class('pupmod::master') }
            it { is_expected.to contain_file('/etc/puppetlabs/puppet').with({
              'ensure' => 'directory',
              'owner'  => 'root',
              'group'  => 'puppet',
              'mode'   => '0640'
            }) }

            it { is_expected.to contain_file('/etc/puppetlabs/puppet/puppet.conf').with({
              'ensure' => 'file',
              'owner'  => 'root',
              'group'  => 'puppet',
              'mode'   => '0640',
              'audit'  => 'content'
            }) }
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
              'subscribe'  => 'File[/etc/puppetlabs/puppet/puppet.conf]'
            }) }
          end

          context 'with non-empty splaylimit' do
            let(:params) {{:splaylimit => 5}}
            it { is_expected.to contain_pupmod__conf('splaylimit').with({
              'setting' => 'splaylimit',
              'value' => 5
            }) }

            it { is_expected.to contain_ini_setting("pupmod_splaylimit") }

          end

          context 'with auditd_support => false' do
            let(:params) {{:auditd_support => false}}
            it { is_expected.to_not contain_class('auditd') }
            it { is_expected.to_not contain_auditd__add_rules('puppet_master') }
          end
        end

      end
    end
end
