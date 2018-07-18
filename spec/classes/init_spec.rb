require 'spec_helper'
require 'yaml'
require 'pry'
require 'pry-byebug'
audit_content = File.open("#{File.dirname(__FILE__)}/data/auditd.txt", "rb").read;
data = YAML.load_file("#{File.dirname(__FILE__)}/data/moduledata.yaml")


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
      [
        'PC1',
        'PE'
      ].each do |distribution|
        context "with server_distribution = #{distribution}" do
          let(:params) {{ :server_distribution => distribution, :puppet_server => '1.2.3.4' }}
          describe "with default parameters" do
            it { is_expected.to create_class('pupmod') }
            it { is_expected.to compile.with_all_deps }
            it { is_expected.not_to contain_class('haveged') }
            it { is_expected.to contain_package('puppet-agent').with_ensure('installed') }
            it { is_expected.to contain_class('pupmod::agent::cron') }
            it { is_expected.to contain_pupmod__conf('agent_daemonize').with({
              'section' => 'agent',
              'setting' => 'daemonize',
              'value' => 'false'
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
              'value' => facts[:domain]
            }) }

            it { is_expected.to contain_pupmod__conf('certname').with({
              'setting' => 'certname',
              'value' => facts[:fqdn]
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

            it { is_expected.to contain_ini_setting("pupmod_splay") }

            it { is_expected.to contain_ini_setting("pupmod_syslogfacility") }

            it { is_expected.to contain_ini_setting("pupmod_srv_domain") }

            it { is_expected.to contain_ini_setting("pupmod_certname") }

            it { is_expected.to contain_ini_setting("pupmod_vardir") }

            it { is_expected.to contain_ini_setting("pupmod_classfile") }

            it { is_expected.to contain_ini_setting("pupmod_confdir") }

            it { is_expected.to contain_ini_setting("pupmod_logdir") }

            it { is_expected.to_not contain_class('auditd') }
            it { is_expected.to_not contain_auditd__rule('puppet_master').with_content(audit_content)}
            it { is_expected.to contain_ini_setting("pupmod_rundir") }

            it { is_expected.to contain_ini_setting("pupmod_runinterval") }

            it { is_expected.to contain_ini_setting("pupmod_ssldir") }

            it { is_expected.to contain_ini_setting("pupmod_stringify_facts") }

            it { is_expected.to contain_ini_setting("pupmod_digest_algorithm") }

            it { is_expected.to_not contain_class('auditd') }
            it { is_expected.to_not contain_auditd__add_rules('puppet_master').with_content(audit_content)}

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

            it { is_expected.to contain_cron('puppet_crl_pull').with_ensure('absent') }

            it { is_expected.to contain_cron('puppet_crl_pull').with_ensure('absent') }

            [
                false,
                true
            ].each do |pe_included|
              context "with puppet_enterprise in the catalog is #{pe_included}" do
                if (pe_included == true)
                  let(:pre_condition) {
                    'include ::puppet_enterprise'
                  }
                end
                if (pe_included == true or distribution == 'PE')
                  $pe_mode = true
                else
                  $pe_mode = false
                end
                let(:title) { "main" }

                {
                    'server' => {
                        'value' => '1.2.3.4'
                    },
                    'ca_server' => {
                        'value' => '$server'
                    },
                    'masterport' => {
                        'value' => 8140
                    },
                    'report' => {
                        'value' => false,
                        'section' => 'agent'
                    },
                    'ca_port' => {
                        'value' => 8141
                    }
                }.each do |key, value|
                  if $pe_mode
                    it { is_expected.to_not contain_ini_setting("pupmod_#{key}") }
                  else
                    it {
                      is_expected.to contain_pupmod__conf(key).with(
                          {
                              'setting' => key
                          }.merge(value)
                      )
                    }
                    it { is_expected.to contain_ini_setting("pupmod_#{key}") }
                  end

                end
                unless $pe_mode
                  mode = '0640'
                else
                  mode = nil
                end
                it { is_expected.to contain_file('/etc/puppetlabs/puppet').with({
                                                                                    'ensure' => 'directory',
                                                                                    'owner'  => 'root',
                                                                                    'group'  => 'puppet',
                                                                                    'mode'   => mode,
                                                                                }) }
                it { is_expected.to contain_file('/etc/puppetlabs/puppet/puppet.conf').with({
                                                                                                'ensure' => 'file',
                                                                                                'owner'  => 'root',
                                                                                                'group'  => 'puppet',
                                                                                                'mode'   => mode
                                                                                            }) }
                it { is_expected.to contain_group('puppet').with({
                                                                     'ensure' => 'present',
                                                                     'allowdupe'  => false,
                                                                     'gid'  => '52',
                                                                     'tag'   => 'firstrun',
                                                                 }) }


                if $pe_mode
                  classlist = data['pupmod::pe_classlist'];
                  classlist.each do |key, value|
                    unless (key == 'pupmod' or key == 'pupmod::master')
                      if (key == 'puppet_enterprise::profile::master')
                        let(:params) {{ :server_distribution => distribution, :puppet_server => '1.2.3.4', :enable_puppet_master => true}}
                      end
                      context "when #{key} is included in the catalog" do
                        let(:pre_condition) {
                          ret = %{
                            include puppet_enterprise
                            include #{key}
                          }

                          if defined?(data)
                            _services = []
                            data['pupmod::pe_classlist'].each_pair { |k,v|
                              _services += v['services'] if v['services']
                            }

                            _services.uniq.each do |_service|
                              ret << %{\nensure_resource('service', '#{_service}')}
                            end
                          end

                          ret
                        }

                        users = value['users']
                        unless (users == nil)
                          users.each do |user|
                            it "should contain Group[puppet] with user #{user} in the members array" do
                              members = catalogue.resource('group', 'puppet').send(:parameters)[:members]
                              expect(members.find { |x| x =~ Regexp.new("#{user}")}).to be_truthy
                            end
                          end
                        end

                        services = value['services']
                        unless (services == nil)
                          services.each do |service|
                            it "should contain Group[puppet] that notifies Service[#{service}]" do
                              notify = catalogue.resource('group', 'puppet').send(:parameters)[:notify]
                              regex = Regexp.new("#{service}")
                              expect(notify.find { |x| x.to_s =~ Regexp.new(regex)}).to be_truthy
                            end
                          end
                        end

                        firewall = value['firewall_rules']
                        unless (firewall == nil)
                          firewall.each do |rule|
                            let(:params) {
                              {
                                  'firewall' => true
                              }
                            }
                            it { is_expected.to contain_iptables__listen__tcp_stateful("#{key} - #{rule['proto']} - #{rule['port']}").with({ 'dports' => rule['port']})}
                          end
                        end
                      end
                    end
                  end
                end

                if $pe_mode
                  context "with pupmod::master defined" do
                    let(:params) {{ :server_distribution => distribution, :puppet_server => '1.2.3.4', :enable_puppet_master => true}}

                    let(:pre_condition) {
                      '
                      include ::puppet_enterprise
                      include ::puppet_enterprise::profile::master
                    '
                    }
                    it {is_expected.to compile.and_raise_error(/.*pupmod::master is NOT supported on PE masters. Please remove the pupmod::master classification from hiera or the puppet console before proceeding.*/) }

                  end
                  context "with pupmod::master not defined" do
                    let(:params) {{ :server_distribution => distribution, :puppet_server => '1.2.3.4', :enable_puppet_master => false}}

                    let(:pre_condition) {
                      '
                      include ::puppet_enterprise
                      include ::puppet_enterprise::profile::master
                    '
                    }
                    it { is_expected.to compile }
                    it { is_expected.to contain_class("pupmod::params")}
                    {
                        "2015.1.1" => true,
                        "2015.20.1" => true,
                        "2016.1.0" => true,
                        "2016.2.0" => true,
                        "2016.4.0" => false,
                        "2016.4.1" => false,
                        "2016.5.1" => false,
                        "2017.1.0" => false,
                        "2017.20.1" => false,
                        "2018.1.0" => false,
                        "2020.1.0" => false,
                        "2021.1.0" => false,
                    }.each do |pe_version, tmpdir|
                      it { is_expected.to contain_file("/opt/puppetlabs/server/data/puppetserver/pserver_tmp")}
                      context "when pe_version == #{pe_version}" do
                        let (:facts) do
                          { "pe_build" => pe_version }.merge(facts)
                        end
                        if (tmpdir == true)
                          it { is_expected.to contain_pe_ini_subsetting("pupmod::master::sysconfig::javatempdir")}
                        else
                          it { is_expected.to_not contain_pe_ini_subsetting("pupmod::master::sysconfig::javatempdir")}
                        end
                      end
                    end
                  end
                end
              end
            end

            context 'with_selinux_disabled' do
              let(:facts) {
                _facts = @extras.merge(os_facts)
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

          end
        end
      end
    end
  end
end
