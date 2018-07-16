require 'spec_helper'

audit_content = File.open("#{File.dirname(__FILE__)}/data/auditd.txt", "rb").read;

describe 'pupmod::master' do
  before :all do
    @extras = { :puppet_settings => {
      'master' => {
        'rest_authconfig' => '/etc/puppetlabs/puppet/authconf.conf'
    }}}
  end

  puppetserver_versions = ['2.7.0', '5.0.0', '5.1.0']

  on_supported_os.each do |os, os_facts|
    puppetserver_versions.each do |puppetserver_version|
      context "on #{os} with puppet server #{puppetserver_version}" do

        def server_facts_hash
          return {
            'serverversion' => puppetserver_version,
            'servername'    => facts[:fqdn],
            'serverip'      => facts[:ipaddress]
          }
        end

        let(:puppetserver_version) { puppetserver_version }

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
          it { is_expected.to contain_class('pupmod::master::sysconfig').that_comes_before('Service[puppetserver]') }
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
            'require' => 'Package[puppetserver]',
            'notify'  => 'Service[puppetserver]'
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
            'require' => 'Package[puppetserver]',
            'notify'  => 'Service[puppetserver]',
            'content' => %q~<!--
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
~
          }) }

          context 'when processing ca.conf' do
            let(:ca_conf) { '/etc/puppetlabs/puppetserver/conf.d/ca.conf' }
            let(:ca_conf_hash) { Hocon.parse(catalogue.resource("File[#{ca_conf}]")['content']) }

            it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d/ca.conf').with({
              'ensure'  => 'file',
              'owner'   => 'root',
              'group'   => 'puppet',
              'mode'    => '0640',
              'require' => 'Package[puppetserver]',
              'notify'  => 'Service[puppetserver]'
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
              'require' => 'Package[puppetserver]',
              'notify'  => 'Service[puppetserver]'
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
                'max-requests-per-instance'       => 0,
                'borrow-timeout'                  => 1200000,
                'environment-class-cache-enabled' => true,
                'compile-mode'                    => 'off',
                'use-legacy-auth-conf'            => false
              }

              if puppetserver_version >= '5.1.0'
                puppetserver_tgt_hash['max-queued-requests']   = 10
                puppetserver_tgt_hash['max-retry-delay']       = 1800
                puppetserver_tgt_hash['profiling-mode']        = 'off'
                puppetserver_tgt_hash['profiling-output-file'] = '/opt/puppetlabs/server/data/puppetserver/server_jruby_profiling'
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
              'require' => 'Package[puppetserver]',
              'notify'  => 'Service[puppetserver]'
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
              'require' => 'Package[puppetserver]',
              'notify'  => 'Service[puppetserver]'
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
                  'ssl-port'          => 8141
                }
              )
            }
          end

          it { is_expected.to contain_pupmod__conf('trusted_server_facts').with({
            'setting' => 'trusted_server_facts',
            'value'   => true,
            'notify'  => 'Service[puppetserver]'
          }) }

          it { is_expected.to contain_pupmod__conf('master_environmentpath').with({
            'section' => 'master',
            'setting' => 'environmentpath',
            'value'   => '/etc/puppetlabs/code/environments',
            'notify'  => 'Service[puppetserver]'
          }) }

          it { is_expected.to contain_pupmod__conf('master_daemonize').with({
            'section' => 'master',
            'setting' => 'daemonize',
            'value'   => 'true',
            'notify'  => 'Service[puppetserver]'
          }) }

          it { is_expected.to contain_pupmod__conf('master_masterport').with({
            'section' => 'master',
            'setting' => 'masterport',
            'value'   => 8140,
            'notify'  => 'Service[puppetserver]'
          }) }

          it { is_expected.to contain_pupmod__conf('master_ca').with({
            'section' => 'master',
            'setting' => 'ca',
            'value'   => true,
            'notify'  => 'Service[puppetserver]'
          }) }

          it { is_expected.to contain_pupmod__conf('master_ca_port').with({
            'section' => 'master',
            'setting' => 'ca_port',
            'value'   => 8141,
            'notify'  => 'Service[puppetserver]'
          }) }

          it { is_expected.to contain_pupmod__conf('ca_ttl').with({
            'section' => 'master',
            'setting' => 'ca_ttl',
            'value'   => '10y',
            'notify'  => 'Service[puppetserver]'
          }) }

          # fips_enabled fact take precedence over hieradata use_fips
          it { is_expected.to contain_pupmod__conf('keylength').with({
            'section' => 'master',
            'setting' => 'keylength',
            'value'   => 4096,
            'notify'  => 'Service[puppetserver]'
          }) }

          it { is_expected.to contain_pupmod__conf('freeze_main').with({
            'setting' => 'freeze_main',
            'value'   => false,
            'notify'  => 'Service[puppetserver]'
          }) }
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
            let(:params) {{:server_distribution => 'PE'}}

            let(:facts){
              @extras.merge(os_facts).merge(
                  :memorysize_mb => '490.16',
                  :pe_build      => '2016.1.0'
              )
            }

            it 'sets $tmpdir via a pe_ini_subsetting resource' do
              expect(catalogue).to contain_pe_ini_subsetting('pupmod::master::sysconfig::javatempdir').with(
                  'value' => %r{/pserver_tmp$},
                  'path'  => '/etc/sysconfig/pe-puppetserver',
                  )
            end

            it { is_expected.to contain_service('pe-puppetserver') }
            it { is_expected.not_to contain_service('puppetserver') }
          end

          context 'when server_distribution => PC1' do
            let(:params) {{:server_distribution => 'PC1'}}
            let(:facts){ @extras.merge(os_facts).merge(:memorysize_mb => '490.16') }

            puppetserver_content = File.open("#{File.dirname(__FILE__)}/master/data/puppetserver.txt", "rb").read

            it { is_expected.to contain_file('/etc/sysconfig/puppetserver').with(
                {
                    'owner'   => 'root',
                    'group'   => 'puppet',
                    'mode'    => '0640',
                    'content' => puppetserver_content
                }
            )}
            it { is_expected.to create_class('pupmod::master::sysconfig') }
            it { is_expected.to contain_file('/opt/puppetlabs/server/data/puppetserver/pserver_tmp').with(
                {
                    'owner'  => 'puppet',
                    'group'  => 'puppet',
                    'ensure' => 'directory',
                    'mode'   => '0750'
                }
            )}

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
                'require' => 'Package[puppetserver]',
                'notify'  => 'Service[puppetserver]'
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
              'require' => 'Package[puppetserver]',
              'notify'  => 'Service[puppetserver]',
              'content' => %q~<!--
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
~
          }) }
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
                'require' => 'Package[puppetserver]',
                'notify'  => 'Service[puppetserver]'
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
                'require' => 'Package[puppetserver]',
                'notify'  => 'Service[puppetserver]'
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
              :ssl_cipher_suites => ['suite1', 'suite2'],
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
