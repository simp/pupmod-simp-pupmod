require 'spec_helper'

describe 'pupmod::master' do
  audit_content = File.open("#{File.dirname(__FILE__)}/data/auditd.txt", "rb").read

  before :all do
    @extras = { :puppet_settings => {
      'master' => {
        'rest_authconfig' => '/etc/puppetlabs/puppet/authconf.conf'
    }}}
  end

  puppetserver_versions = ['6.1.0', '5.3.5', '5.0.0', '2.7.0']

  on_supported_os.each do |os, os_facts|
    target_os = ENV.fetch('SPEC_SUPPORTED_OS', os)
    next unless target_os == os

    puppetserver_versions.each do |puppetserver_version|
      context "on #{os} with puppet server #{puppetserver_version}" do

        def server_facts_hash
          return {
            'serverversion' => puppetserver_version,
            'servername'    => facts[:fqdn],
            'serverip'      => facts[:ipaddress]
          }
        end

        let(:facts){
          facts = @extras.merge(os_facts)
          facts[:simp_pupmod_serverversion] = puppetserver_version

          facts
        }

        describe "with default parameters" do

          let(:ca_cfg) { '/etc/puppetlabs/puppetserver/services.d/ca.cfg' }
          let(:ca_cfg_lines) { catalogue.resource("File[#{ca_cfg}]")['content'].lines.map(&:strip).select{|l| l !~ /^\s*(#.+)?$/} }

          it { is_expected.to compile.with_all_deps }

          it { is_expected.to create_class('pupmod') }
          it { is_expected.to create_class('pupmod::master::sysconfig') }
          it { is_expected.to create_class('pupmod::master::reports') }
          it { is_expected.to create_class('pupmod::master::base') }
          it { is_expected.to contain_class('pupmod::master::sysconfig').that_comes_before('Class[Pupmod::Master::Service]') }
          it { is_expected.to contain_file('/etc/puppetlabs/puppetserver').with({
            'ensure' => 'directory',
            'owner'  => 'root',
            'group'  => 'puppet',
            'mode'   => '0640'
          }) }

          it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d').with({
            'ensure' => 'directory',
            'owner'  => 'root',
            'group'  => 'puppet',
            'mode'   => '0640'
          }) }

          it { is_expected.to contain_file('/etc/puppetlabs/puppet/ssl').with({
            'ensure' => 'directory',
            'owner'  => 'puppet',
            'group'  => 'puppet'
          }) }

          it { is_expected.to contain_file('/var/run/puppetlabs/puppetserver').with({
            'ensure' => 'directory',
            'owner'  => 'puppet',
            'group'  => 'puppet'
          }) }

          it { is_expected.to contain_file('/etc/puppetlabs/code').with({
            'ensure' => 'directory',
            'owner'  => 'root',
            'group'  => 'puppet',
            'mode'   => '0640'
          }) }

          it { is_expected.to contain_file(ca_cfg).with({
            'ensure'  => 'file',
            'owner'   => 'root',
            'group'   => 'puppet',
            'mode'    => '0640',
            'require' => 'Class[Pupmod::Master::Install]',
            'notify'  => 'Class[Pupmod::Master::Service]'
          }) }

          if puppetserver_version >= '5.1.0'
            it { expect(ca_cfg_lines).to eq ([
              'puppetlabs.services.ca.certificate-authority-service/certificate-authority-service',
              'puppetlabs.trapperkeeper.services.watcher.filesystem-watch-service/filesystem-watch-service'
            ]) }
          else
            it { expect(ca_cfg_lines).to eq ([
              'puppetlabs.services.ca.certificate-authority-service/certificate-authority-service'
            ]) }
          end

          it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/logback.xml').with({
            'ensure'  => 'file',
            'owner'   => 'root',
            'group'   => 'puppet',
            'mode'    => '0640',
            'require' => 'Class[Pupmod::Master::Install]',
            'notify'  => 'Class[Pupmod::Master::Service]',
            'content' => <<~CONTENT
              <!--
                This file managed by Puppet.
                Any changes will be erased at the next run.
              -->
              <configuration>
                  <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
                      <encoder>
                          <pattern>%d %-5p [%c{2}] %m%n</pattern>
                      </encoder>
                  </appender>

                  <appender name="SYSLOG" class="ch.qos.logback.classic.net.SyslogAppender">
                    <syslogHost>localhost</syslogHost>
                    <facility>LOCAL6</facility>
                    <suffixPattern>%logger[%thread]: %msg</suffixPattern>
                    <throwableExcluded>true</throwableExcluded>
                  </appender>

                  <appender name="F1" class="ch.qos.logback.core.FileAppender">
                      <file>/var/log/puppetlabs/puppetserver/puppetserver.log</file>
                      <append>true</append>
                      <encoder>
                          <pattern>%d %-5p [%c{2}] %m%n</pattern>
                      </encoder>
                  </appender>

                  <logger name="org.eclipse.jetty" level="WARN"/>

                  <root level="WARN">
                  </root>
              </configuration>
              CONTENT
          }) }

          context 'when processing ca.conf' do
            let(:ca_conf) { '/etc/puppetlabs/puppetserver/conf.d/ca.conf' }
            let(:ca_conf_hash) { Hocon.parse(catalogue.resource("File[#{ca_conf}]")['content']) }

            it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d/ca.conf').with({
              'ensure'  => 'file',
              'owner'   => 'root',
              'group'   => 'puppet',
              'mode'    => '0640',
              'require' => 'Class[Pupmod::Master::Install]',
              'notify'  => 'Class[Pupmod::Master::Service]'
            }) }

            it { expect(ca_conf_hash).to have_key('certificate-authority') }
            it {
              expect(ca_conf_hash['certificate-authority']).to eq(
                'certificate-status' => {
                  'client-whitelist'       => [facts[:fqdn]],
                  'authorization-required' => true
                }
              )
            }
          end

          it { is_expected.to_not contain_file('/etc/puppetlabs/puppetserver/conf.d/os-settings.conf') }

          context 'when processing puppetserver.conf' do
            let(:puppetserver_conf) { '/etc/puppetlabs/puppetserver/conf.d/puppetserver.conf' }
            let(:puppetserver_conf_hash) { Hocon.parse(catalogue.resource("File[#{puppetserver_conf}]")['content']) }

            it { is_expected.to contain_file(puppetserver_conf).with({
              'ensure'  => 'file',
              'owner'   => 'root',
              'group'   => 'puppet',
              'mode'    => '0640',
              'require' => 'Class[Pupmod::Master::Install]',
              'notify'  => 'Class[Pupmod::Master::Service]'
            }) }

            it { expect(puppetserver_conf_hash).to have_key('jruby-puppet') }

            it {
              puppetserver_tgt_hash = {
                'ruby-load-path'                  => [ '/opt/puppetlabs/puppet/lib/ruby/vendor_ruby' ],
                'gem-home'                        => '/opt/puppetlabs/server/data/puppetserver/jruby-gems',
                'master-conf-dir'                 => '/etc/puppetlabs/puppet',
                'master-code-dir'                 => '/etc/puppetlabs/code',
                'master-run-dir'                  => '/var/run/puppetlabs/puppetserver',
                'master-log-dir'                  => '/var/log/puppetlabs/puppetserver',
                'master-var-dir'                  => '/opt/puppetlabs/server/data/puppetserver',
                'max-active-instances'            => 1,
                'max-requests-per-instance'       => 100000,
                'borrow-timeout'                  => 1200000,
                'environment-class-cache-enabled' => true,
                'compile-mode'                    => 'off',
                'use-legacy-auth-conf'            => false
              }

              if puppetserver_version >= '5.1.0'
                puppetserver_tgt_hash['max-queued-requests']   = 10
                puppetserver_tgt_hash['max-retry-delay']       = 1800
                puppetserver_tgt_hash['profiling-mode']        = 'off'
                puppetserver_tgt_hash['profiler-output-file'] = '/opt/puppetlabs/server/data/puppetserver/server_jruby_profiling'
              end

              if puppetserver_version >= '6.0.0'
                puppetserver_tgt_hash['gem-path'] = [
                  '/opt/puppetlabs/server/data/puppetserver/jruby-gems',
                  '/opt/puppetlabs/server/data/puppetserver/vendored-jruby-gems',
                  '/opt/puppetlabs/puppet/lib/ruby/vendor_gems'
                ]
              end

              expect(puppetserver_conf_hash['jruby-puppet']).to eq(puppetserver_tgt_hash)
            }

            it { expect(puppetserver_conf_hash).to have_key('http-client') }
            it {
              expect(puppetserver_conf_hash['http-client']).to eq(
                'ssl-protocols' => [ 'TLSv1', 'TLSv1.1', 'TLSv1.2' ]
              )
            }

            it { expect(puppetserver_conf_hash).to have_key('profiler') }
            it {
              expect(puppetserver_conf_hash['profiler']).to eq(
                'enabled' => false
              )
            }

            it { expect(puppetserver_conf_hash).to have_key('puppet-admin') }
            it {
              expect(puppetserver_conf_hash['puppet-admin']).to eq(
                'client-whitelist' => [ facts[:fqdn] ]
              )
            }
          end

          context 'when processing web-routes.conf' do
            let(:web_routes_conf) { '/etc/puppetlabs/puppetserver/conf.d/web-routes.conf' }
            let(:web_routes_conf_hash) { Hocon.parse(catalogue.resource("File[#{web_routes_conf}]")['content']) }

            it { is_expected.to contain_file(web_routes_conf).with({
              'ensure'  => 'file',
              'owner'   => 'root',
              'group'   => 'puppet',
              'mode'    => '0640',
              'require' => 'Class[Pupmod::Master::Install]',
              'notify'  => 'Class[Pupmod::Master::Service]'
            }) }

            it { expect(web_routes_conf_hash).to have_key('web-router-service') }

            it {
              web_router_service_hash = {
                'puppetlabs.services.ca.certificate-authority-service/certificate-authority-service' => {
                  'default' => {
                    'route'  => '/puppet-ca',
                    'server' => 'ca'
                  }
                },
                'puppetlabs.trapperkeeper.services.status.status-service/status-service'        => '/status',
                'puppetlabs.services.master.master-service/master-service'                      => '/puppet',
                'puppetlabs.services.legacy-routes.legacy-routes-service/legacy-routes-service' => '',
                'puppetlabs.services.puppet-admin.puppet-admin-service/puppet-admin-service'    => '/puppet-admin-api'
              }

              if puppetserver_version >= '5.1.0'
                web_router_service_hash['puppetlabs.trapperkeeper.services.metrics.metrics-service/metrics-webservice'] = '/metrics'
              end

              expect(web_routes_conf_hash['web-router-service']).to eq(web_router_service_hash)
            }
          end

          context 'when processing webserver.conf' do
            let(:webserver_conf) { '/etc/puppetlabs/puppetserver/conf.d/webserver.conf' }
            let(:webserver_conf_hash) { Hocon.parse(catalogue.resource("File[#{webserver_conf}]")['content']) }

            it { is_expected.to contain_file(webserver_conf).with({
              'ensure'  => 'file',
              'owner'   => 'root',
              'group'   => 'puppet',
              'mode'    => '0640',
              'require' => 'Class[Pupmod::Master::Install]',
              'notify'  => 'Class[Pupmod::Master::Service]'
            }) }

            it { expect(webserver_conf_hash).to have_key('webserver') }
            it {
              expect(webserver_conf_hash['webserver']).to eq(
                'base' => {
                  'access-log-config' => '/etc/puppetlabs/puppetserver/request-logging.xml',
                  'client-auth'       => 'need',
                  'ssl-crl-path'      => '/etc/puppetlabs/puppet/ssl/crl.pem',
                  'ssl-ca-cert'       => '/etc/puppetlabs/puppet/ssl/certs/ca.pem',
                  'ssl-cert'          => "/etc/puppetlabs/puppet/ssl/certs/#{facts[:fqdn]}.pem",
                  'ssl-key'           => "/etc/puppetlabs/puppet/ssl/private_keys/#{facts[:fqdn]}.pem",
                  'ssl-host'          => '0.0.0.0',
                  'ssl-port'          => 8140,
                  'ssl-protocols'     => 'TLSv1,TLSv1.1,TLSv1.2',
                  'default-server'    => true
                },
                'ca'   => {
                  'access-log-config' => '/etc/puppetlabs/puppetserver/request-logging.xml',
                  'client-auth'       => 'want',
                  'ssl-crl-path'      => '/etc/puppetlabs/puppet/ssl/crl.pem',
                  'ssl-ca-cert'       => '/etc/puppetlabs/puppet/ssl/certs/ca.pem',
                  'ssl-cert'          => "/etc/puppetlabs/puppet/ssl/certs/#{facts[:fqdn]}.pem",
                  'ssl-key'           => "/etc/puppetlabs/puppet/ssl/private_keys/#{facts[:fqdn]}.pem",
                  'ssl-host'          => '0.0.0.0',
                  'ssl-port'          => 8141,
                  'ssl-protocols'     => 'TLSv1,TLSv1.1,TLSv1.2',
                }
              )
            }
            it { expect(webserver_conf_hash['webserver']['base']['cipher-suites']).to be_nil }
            it { expect(webserver_conf_hash['webserver']['ca']['cipher-suites']).to be_nil }

            context 'when setting the cipher suites' do
              let(:params) {{
                :ssl_cipher_suites => ['TLS_RSA_WITH_AES_256_CBC_SHA256', 'TLS_RSA_WITH_AES_128_CBC_SHA256']
              }}

              it { expect(webserver_conf_hash['webserver']['base']['cipher-suites']).to eq(params[:ssl_cipher_suites].join(',')) }
              it { expect(webserver_conf_hash['webserver']['ca']['cipher-suites']).to eq(params[:ssl_cipher_suites].join(',')) }
            end

            context 'when setting aribtrary webserver options' do
              let(:params) {{
                # Simple setting override
                :server_webserver_options => {
                  'port' => '1212'
                },
                # Complex setting
                :ca_webserver_options => {
                  'static-content' => '[{ resource: "./web-assets", path: "/assets" }]'
                }
              }}

              it { expect(webserver_conf_hash['webserver']['base']['port']).to eq(1212) }
              it {
                expect(webserver_conf_hash['webserver']['ca']['static-content']).to eq([{
                  'resource' => './web-assets',
                  'path'     => '/assets'
                }])
              }
            end

            context 'when adding new webserver sections' do
              let(:params) {{
                # Simple setting override
                :extra_webserver_sections => {
                  'bob' => {
                    'port' => '1212',
                    'static-content' => '[{ resource: "./web-assets", path: "/assets" }]'
                  },
                  'alice' => {
                    'port' => '2345',
                    'static-content' => '[{ resource: "./other-web-assets", path: "/other-assets" }]'
                  }
                }
              }}

              it { expect(webserver_conf_hash['webserver']['bob']['port']).to eq(1212) }
              it {
                expect(webserver_conf_hash['webserver']['bob']['static-content']).to eq([{
                  'resource' => './web-assets',
                  'path'     => '/assets'
                }])
              }
              it { expect(webserver_conf_hash['webserver']['alice']['port']).to eq(2345) }
              it {
                expect(webserver_conf_hash['webserver']['alice']['static-content']).to eq([{
                  'resource' => './other-web-assets',
                  'path'     => '/other-assets'
                }])
              }
            end
          end

          it 'handles `trusted_server_facts` correctly for the Puppet version' do
            if (Puppet.version.split('.').first >= '5')
              is_expected.to contain_pupmod__conf('trusted_server_facts').with({
                'ensure' => 'absent'
              })
            else
              is_expected.to contain_pupmod__conf('trusted_server_facts').with({
                'ensure'  => 'present',
                'setting' => 'trusted_server_facts',
                'value'   => true,
                'notify'  => 'Class[Pupmod::Master::Service]'
              })
            end
          end

          it { is_expected.to contain_pupmod__conf('master_environmentpath').with({
            'section' => 'master',
            'setting' => 'environmentpath',
            'value'   => '/etc/puppetlabs/code/environments',
            'notify'  => 'Class[Pupmod::Master::Service]'
          }) }

          it { is_expected.to contain_pupmod__conf('master_daemonize').with({
            'section' => 'master',
            'setting' => 'daemonize',
            'value'   => 'true',
            'notify'  => 'Class[Pupmod::Master::Service]'
          }) }

          it { is_expected.to contain_pupmod__conf('master_masterport').with({
            'section' => 'master',
            'setting' => 'masterport',
            'value'   => 8140,
            'notify'  => 'Class[Pupmod::Master::Service]'
          }) }

          if (Gem::Version.new(Puppet.version) >= Gem::Version.new('5.5.6'))
            it 'ensures that "[master] ca" is absent when Puppet >= 5.5.6' do
              is_expected.to contain_pupmod__conf('master_ca').with_ensure('absent')
            end
          else
            it 'ensures that "[master] ca = true" is absent when Puppet < 5.5.6' do
              is_expected.to contain_pupmod__conf('master_ca').with({
                'section' => 'master',
                'setting' => 'ca',
                'value'   => true,
                'notify'  => 'Class[Pupmod::Master::Service]',
              })
            end
          end

          it { is_expected.to contain_pupmod__conf('master_ca_port').with({
            'section' => 'master',
            'setting' => 'ca_port',
            'value'   => 8141,
            'notify'  => 'Class[Pupmod::Master::Service]'
          }) }

          it { is_expected.to contain_pupmod__conf('ca_ttl').with({
            'section' => 'master',
            'setting' => 'ca_ttl',
            'value'   => '10y',
            'notify'  => 'Class[Pupmod::Master::Service]'
          }) }

          # fips_enabled fact take precedence over hieradata use_fips
          it { is_expected.to contain_pupmod__conf('keylength').with({
            'section' => 'master',
            'setting' => 'keylength',
            'value'   => 4096,
            'notify'  => 'Class[Pupmod::Master::Service]'
          }) }

          it { is_expected.to contain_pupmod__conf('freeze_main').with({
            'setting' => 'freeze_main',
            'value'   => false,
            'notify'  => 'Class[Pupmod::Master::Service]'
          }) }

          it { is_expected.to contain_pupmod__conf('strict_hostname_checking').with({
              'setting' => 'strict_hostname_checking',
              'value'   => true,
              'notify'  => 'Class[Pupmod::Master::Service]'
            })
          }

          it { is_expected.to contain_ini_setting("pupmod_master_environmentpath") }

          it { is_expected.to contain_ini_setting("pupmod_master_daemonize") }

          it { is_expected.to contain_ini_setting("pupmod_master_masterport") }

          it { is_expected.to contain_ini_setting("pupmod_master_ca") }

          it { is_expected.to contain_ini_setting("pupmod_master_ca_port") }

          it { is_expected.to contain_ini_setting("pupmod_ca_ttl") }

          it { is_expected.to contain_ini_setting("pupmod_keylength") }

          it { is_expected.to contain_ini_setting("pupmod_freeze_main") }

          it { is_expected.not_to contain_class('iptables') }
          it { is_expected.not_to contain_iptables__listen__tcp_stateful('allow_puppet') }
          it { is_expected.not_to contain_iptables__listen__tcp_stateful('allow_puppetca') }
        end

        describe "with non-default parameters" do
          context 'when server_distribution => PE' do
            let(:hieradata) { 'pe' }

            it { is_expected.not_to contain_service('puppetserver') }
          end

          context 'when server_distribution => PC1' do
            let(:params) {{:server_distribution => 'PC1'}}

            it { is_expected.to contain_service('puppetserver') }
            it { is_expected.not_to contain_service('pe-puppetserver') }
          end

          context 'with enable_ca => false' do
            let(:params) {{:enable_ca => false}}

            context 'when processing web-routes.conf' do
              let(:web_routes_conf) { '/etc/puppetlabs/puppetserver/conf.d/web-routes.conf' }
              let(:web_routes_conf_hash) { Hocon.parse(catalogue.resource("File[#{web_routes_conf}]")['content']) }

              let(:ca_cfg) { '/etc/puppetlabs/puppetserver/services.d/ca.cfg' }
              let(:ca_cfg_lines) { catalogue.resource("File[#{ca_cfg}]")['content'].lines.map(&:strip).select{|l| l !~ /^\s*(#.+)?$/} }

              it { is_expected.to contain_file(web_routes_conf) }
              it { expect(web_routes_conf_hash). to have_key('web-router-service') }
              it {
                expect(web_routes_conf_hash['web-router-service']).to include(
                  'puppetlabs.services.ca.certificate-authority-service/certificate-authority-service' => '/puppet-ca'
                )
              }

              it { is_expected.to contain_file(ca_cfg).with({
                'ensure'  => 'file',
                'owner'   => 'root',
                'group'   => 'puppet',
                'mode'    => '0640',
                'require' => 'Class[Pupmod::Master::Install]',
                'notify'  => 'Class[Pupmod::Master::Service]'
              }) }

                it { expect(ca_cfg_lines).to eq ([
                  'puppetlabs.services.ca.certificate-authority-disabled-service/certificate-authority-disabled-service'
                ]) }
            end
          end

          context 'with syslog => true and log_to_file => true' do
            let(:params) {{:syslog => true, :log_to_file => true}}
            it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/logback.xml').with({
              'ensure'  => 'file',
              'owner'   => 'root',
              'group'   => 'puppet',
              'mode'    => '0640',
              'require' => 'Class[Pupmod::Master::Install]',
              'notify'  => 'Class[Pupmod::Master::Service]',
              'content' => <<~CONTENT
                <!--
                  This file managed by Puppet.
                  Any changes will be erased at the next run.
                -->
                <configuration>
                    <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
                        <encoder>
                            <pattern>%d %-5p [%c{2}] %m%n</pattern>
                        </encoder>
                    </appender>

                    <appender name="SYSLOG" class="ch.qos.logback.classic.net.SyslogAppender">
                      <syslogHost>localhost</syslogHost>
                      <facility>LOCAL6</facility>
                      <suffixPattern>%logger[%thread]: %msg</suffixPattern>
                      <throwableExcluded>true</throwableExcluded>
                    </appender>

                    <appender name="F1" class="ch.qos.logback.core.FileAppender">
                        <file>/var/log/puppetlabs/puppetserver/puppetserver.log</file>
                        <append>true</append>
                        <encoder>
                            <pattern>%d %-5p [%c{2}] %m%n</pattern>
                        </encoder>
                    </appender>

                    <logger name="org.eclipse.jetty" level="WARN"/>

                    <root level="WARN">
                        <appender-ref ref="SYSLOG"/>
                        <appender-ref ref="F1"/>
                    </root>
                </configuration>
                CONTENT
          }) }
          end

          context 'strict_hostname_checking = false' do
            let(:params) {{ :strict_hostname_checking => false }}

            it { is_expected.to contain_notify('CVE-2020-7942') }

            context 'cve_2020_7942_warning = false' do
              let(:params) {{
                :strict_hostname_checking => false,
                :cve_2020_7942_warning    => false
              }}

              it { is_expected.not_to contain_notify('CVE-2020-7942') }
            end
          end

          context 'with ca_allow_auth_extensions' do
            let(:params) {{:ca_allow_auth_extensions => true}}

            context 'when processing ca.conf' do
              let(:ca_conf) { '/etc/puppetlabs/puppetserver/conf.d/ca.conf' }
              let(:ca_conf_hash) { Hocon.parse(catalogue.resource("File[#{ca_conf}]")['content']) }

              it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d/ca.conf').with({
                'ensure'  => 'file',
                'owner'   => 'root',
                'group'   => 'puppet',
                'mode'    => '0640',
                'require' => 'Class[Pupmod::Master::Install]',
                'notify'  => 'Class[Pupmod::Master::Service]'
              }) }

              it { expect(ca_conf_hash).to have_key('certificate-authority') }
              it { expect(ca_conf_hash['certificate-authority']).to have_key('allow-authorization-extensions') }
              it {
                expect(ca_conf_hash['certificate-authority']['allow-authorization-extensions']).to be(true)
              }
            end
          end

          context 'with ca_allow_alt_names' do
            let(:params) {{:ca_allow_alt_names => true}}

            context 'when processing ca.conf' do
              let(:ca_conf) { '/etc/puppetlabs/puppetserver/conf.d/ca.conf' }
              let(:ca_conf_hash) { Hocon.parse(catalogue.resource("File[#{ca_conf}]")['content']) }

              it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d/ca.conf').with({
                'ensure'  => 'file',
                'owner'   => 'root',
                'group'   => 'puppet',
                'mode'    => '0640',
                'require' => 'Class[Pupmod::Master::Install]',
                'notify'  => 'Class[Pupmod::Master::Service]'
              }) }

              it { expect(ca_conf_hash).to have_key('certificate-authority') }
              it { expect(ca_conf_hash['certificate-authority']).to have_key('allow-subject-alt-names') }
              it {
                expect(ca_conf_hash['certificate-authority']['allow-subject-alt-names']).to be(true)
              }
            end
          end

          context 'with multiple entries in ca_status_whitelist' do
            let(:params) {{:ca_status_whitelist => ['1.2.3.4', '5.6.7.8']}}

            context 'when processing ca.conf' do
              let(:ca_conf) { '/etc/puppetlabs/puppetserver/conf.d/ca.conf' }
              let(:ca_conf_hash) { Hocon.parse(catalogue.resource("File[#{ca_conf}]")['content']) }

              it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d/ca.conf').with({
                'ensure'  => 'file',
                'owner'   => 'root',
                'group'   => 'puppet',
                'mode'    => '0640',
                'require' => 'Class[Pupmod::Master::Install]',
                'notify'  => 'Class[Pupmod::Master::Service]'
              }) }

              it { expect(ca_conf_hash).to have_key('certificate-authority') }
              it { expect(ca_conf_hash['certificate-authority']).to have_key('certificate-status') }
              it {
                expect(ca_conf_hash['certificate-authority']['certificate-status']).to include(
                  'client-whitelist'       => params[:ca_status_whitelist],
                  'authorization-required' => true
                )
              }
            end
          end

          context 'with non-empty ruby_load_path' do
            let(:params) {{:ruby_load_path => '/some/ruby/path'}}
              context 'when processing os-settings.conf' do
                let(:os_settings_conf) { '/etc/puppetlabs/puppetserver/conf.d/os-settings.conf' }
                let(:os_settings_conf_hash) { Hocon.parse(catalogue.resource("File[#{os_settings_conf}]")['content']) }

              it { is_expected.to contain_file(os_settings_conf).with({
                'ensure'  => 'file',
                'owner'   => 'root',
                'group'   => 'puppet',
                'mode'    => '0640',
                'require' => 'Class[Pupmod::Master::Install]',
                'notify'  => 'Class[Pupmod::Master::Service]'
              }) }

              it { expect(os_settings_conf_hash).to have_key('os-settings') }
              it {
                expect(os_settings_conf_hash['os-settings']).to include(
                  'ruby-load-path' => [params[:ruby_load_path]].flatten
                )
              }
              end
          end

          context 'with empty ssl_protocols, non-empty ssl_cipher_suites, and multiple admin_api_whitelist entries' do
            let(:params) {{
              :ssl_protocols => [],
              :ssl_cipher_suites => ['TLS_RSA_WITH_AES_256_CBC_SHA256', 'TLS_RSA_WITH_AES_128_CBC_SHA256'],
              :admin_api_whitelist => ['foo.example.com', 'bar.example.com']
            }}

            context 'when processing puppetserver.conf' do
              let(:puppetserver_conf) { '/etc/puppetlabs/puppetserver/conf.d/puppetserver.conf' }
              let(:puppetserver_conf_hash) { Hocon.parse(catalogue.resource("File[#{puppetserver_conf}]")['content']) }

              it { is_expected.to contain_file(puppetserver_conf) }

              it { expect(puppetserver_conf_hash).to have_key('http-client') }
              it { expect(puppetserver_conf_hash['http-client']).to_not have_key('ssl-protocols') }
              it {
                expect(puppetserver_conf_hash['http-client']).to include(
                  'cipher-suites' => params[:ssl_cipher_suites]
                )
              }

              it { expect(puppetserver_conf_hash).to have_key('puppet-admin') }
              it {
                expect(puppetserver_conf_hash['puppet-admin']).to include(
                  'client-whitelist' => params[:admin_api_whitelist]
                )
              }
            end
          end

          context 'when admin_api_mountpoints does not begin with / and enable_ca => false' do
            let(:params) {{
              :admin_api_mountpoint => 'admin_mount_point',
              :enable_ca => false
            }}

            context 'when processing web-routes.conf' do
              let(:web_routes_conf) { '/etc/puppetlabs/puppetserver/conf.d/web-routes.conf' }
              let(:web_routes_conf_hash) { Hocon.parse(catalogue.resource("File[#{web_routes_conf}]")['content']) }

              it { is_expected.to contain_file(web_routes_conf) }

              it { expect(web_routes_conf_hash).to have_key('web-router-service') }
              it {
                expect(web_routes_conf_hash['web-router-service']).to include(
                  'puppetlabs.services.puppet-admin.puppet-admin-service/puppet-admin-service'         => '/' + params[:admin_api_mountpoint],
                  'puppetlabs.services.ca.certificate-authority-service/certificate-authority-service' => '/puppet-ca'
                )
              }
            end
          end

          context 'ca_port == masterport' do
            let(:params) {{
              :ca_port    => 12345,
              :masterport => 12345

            }}

            context 'when processing web-routes.conf' do
              let(:web_routes_conf) { '/etc/puppetlabs/puppetserver/conf.d/web-routes.conf' }
              let(:web_routes_conf_hash) { Hocon.parse(catalogue.resource("File[#{web_routes_conf}]")['content']) }

              it { is_expected.to contain_file(web_routes_conf) }

              it { expect(web_routes_conf_hash).to have_key('web-router-service') }
              it {
                expect(web_routes_conf_hash['web-router-service']).to include(
                  'puppetlabs.services.ca.certificate-authority-service/certificate-authority-service' => '/puppet-ca'
                )
              }
            end
          end

          context 'when enable_master =>false' do
            let(:params) {{ :enable_master => false }}

            context 'when processing webserver.conf' do
              let(:webserver_conf) { '/etc/puppetlabs/puppetserver/conf.d/web-routes.conf' }
              let(:webserver_conf_hash) { Hocon.parse(catalogue.resource("File[#{webserver_conf}]")['content']) }

              it { is_expected.to contain_file(webserver_conf) }

              it { expect(webserver_conf_hash).to_not have_key('base') }
            end

            it { is_expected.to_not contain_iptables__listen__tcp_stateful('allow_puppet') }
          end

          context 'when firewall => true' do
            let(:params) {{ :firewall => true }}
            it { is_expected.to contain_class('iptables') }
            it {
              is_expected.to contain_iptables__listen__tcp_stateful('allow_puppet').with({
                'order'        => '11',
                'trusted_nets' => ['127.0.0.1','::1'],
                'dports'       => 8140
            }) }
            it {
              is_expected.to contain_iptables__listen__tcp_stateful('allow_puppetca').with({
                'order'        => '11',
                'trusted_nets' => ['127.0.0.1','::1'],
                'dports'       => 8141
            }) }
          end

          context 'with auditd => false' do
            let(:params) {{:auditd => false}}
            it { is_expected.to_not contain_class('auditd') }
            it { is_expected.to_not contain_auditd__rule('puppet_master').with_content(audit_content)}
          end

          context 'with auditd => true' do
            let(:params) {{:auditd => true}}
            it { is_expected.to contain_class('auditd') }
            it { is_expected.to contain_auditd__rule('puppet_master').with_content(audit_content)}
          end

          context 'when autosigning' do
            autosign_hosts = ['foo.bar', '*.baz']
            let(:params) {{ :autosign_hosts => autosign_hosts }}

            autosign_hosts.each do |autosign_host|
              it { is_expected.to contain_pupmod__master__autosign(autosign_host) }
            end
          end
        end
      end
    end
  end
end
