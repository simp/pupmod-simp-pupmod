require 'spec_helper'

# pupmod::master::config is private, so it is exercised through pupmod::master
describe 'pupmod::master' do
  def hocon(file, setting)
    "pupmod::master #{file} #{setting}"
  end

  def hocon_titles(pattern)
    catalogue.resources.select { |r| r.type == 'Hocon_setting' && r.title =~ pattern }.map(&:title)
  end

  # The puppetserver_webserver fact for a webserver.conf in conf_d
  def webserver_fact(webserver, dir = '/etc/puppetlabs/puppetserver/conf.d')
    { 'path' => "#{dir}/webserver.conf", 'webserver' => webserver }
  end

  let(:conf_d) { '/etc/puppetlabs/puppetserver/conf.d' }
  let(:ca_route) { 'web-router-service."puppetlabs.services.ca.certificate-authority-service/certificate-authority-service"' }
  let(:admin_route) { 'web-router-service."puppetlabs.services.puppet-admin.puppet-admin-service/puppet-admin-service"' }

  # What the package's webserver.conf holds
  let(:single_server) do
    {
      'access-log-config' => '/etc/puppetlabs/puppetserver/request-logging.xml',
      'client-auth'       => 'want',
      'ssl-host'          => '0.0.0.0',
      'ssl-port'          => 8140,
    }
  end

  # What a pre-13.0.0 pupmod wrote
  let(:named_servers) do
    {
      'base' => { 'ssl-host' => '10.1.1.1', 'ssl-port' => 8140, 'default-server' => true },
      'ca'   => { 'ssl-host' => '10.1.1.1', 'ssl-port' => 8141 },
    }
  end

  on_supported_os.to_a.values_at(0, -1).uniq.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:fqdn) { facts.dig(:networking, :fqdn) || facts.dig(:networking, 'fqdn') }

      describe 'puppetserver.conf, ca.conf and product.conf' do
        {
          max_requests_per_instance: ['puppetserver.conf', 'jruby-puppet.max-requests-per-instance', 100_000, true],
          borrow_timeout: ['puppetserver.conf', 'jruby-puppet.borrow-timeout', 1_200_000, true],
          environment_class_cache_enabled: ['puppetserver.conf', 'jruby-puppet.environment-class-cache-enabled', true, false],
          compile_mode: ['puppetserver.conf', 'jruby-puppet.compile-mode', 'jit', true],
          use_legacy_auth_conf: ['puppetserver.conf', 'jruby-puppet.use-legacy-auth-conf', false, false],
          max_queued_requests: ['puppetserver.conf', 'jruby-puppet.max-queued-requests', 10, true],
          max_retry_delay: ['puppetserver.conf', 'jruby-puppet.max-retry-delay', 1800, true],
          profiling_mode: ['puppetserver.conf', 'jruby-puppet.profiling-mode', 'flat', true],
          profiler_output_file: ['puppetserver.conf', 'jruby-puppet.profiler-output-file', '/var/tmp/profile', true],
          max_active_instances: ['puppetserver.conf', 'jruby-puppet.max-active-instances', 4, true],
          ssl_protocols: ['puppetserver.conf', 'http-client.ssl-protocols', ['TLSv1.2'], true],
          ssl_cipher_suites: ['puppetserver.conf', 'http-client.cipher-suites', ['TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384', 'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256'], true],
          enable_profiler: ['puppetserver.conf', 'profiler.enabled', true, false],
          admin_api_whitelist: ['puppetserver.conf', 'puppet-admin.client-whitelist', ['admin.example.com'], true],
          ca_allow_auth_extensions: ['ca.conf', 'certificate-authority.allow-authorization-extensions', true, false],
          ca_allow_alt_names: ['ca.conf', 'certificate-authority.allow-subject-alt-names', false, false],
          enable_analytics: ['product.conf', 'product.check-for-updates', false, false],
        }.each do |param, (file, setting, value, removable)|
          context "with #{param} set" do
            let(:params) { { param => value } }

            it { is_expected.to compile.with_all_deps }
            it {
              is_expected.to contain_hocon_setting(hocon(file, setting)).with(
                ensure: 'present',
                path: "#{conf_d}/#{file}",
                setting: setting,
                value: value,
              ).that_requires('Class[pupmod::master::install]').that_notifies('Class[pupmod::master::service]')
            }

            if value.is_a?(Array)
              it { is_expected.to contain_hocon_setting(hocon(file, setting)).with_type('array') }
            else
              it { is_expected.to contain_hocon_setting(hocon(file, setting)).without_type }
            end
          end

          next unless removable

          context "with #{param} => 'absent'" do
            let(:params) { { param => 'absent' } }

            it { is_expected.to contain_hocon_setting(hocon(file, setting)).with_ensure('absent') }
          end
        end

        context 'with max_active_instances => auto' do
          let(:params) { { max_active_instances: 'auto' } }

          it {
            expect(catalogue.resource('Hocon_setting', hocon('puppetserver.conf', 'jruby-puppet.max-active-instances'))[:value]).to be_a(Integer)
          }
        end

        ['conf', 'code', 'var', 'run', 'log'].each do |dir|
          context "with server_#{dir}_dir" do
            let(:params) { { "server_#{dir}_dir": "/srv/#{dir}" } }

            it { is_expected.to contain_hocon_setting(hocon('puppetserver.conf', "jruby-puppet.server-#{dir}-dir")).with(ensure: 'present', value: "/srv/#{dir}") }
            it { is_expected.to contain_hocon_setting(hocon('puppetserver.conf', "jruby-puppet.master-#{dir}-dir")).with_ensure('absent') }
          end

          context "with server_#{dir}_dir => 'absent'" do
            let(:params) { { "server_#{dir}_dir": 'absent' } }

            it { is_expected.to contain_hocon_setting(hocon('puppetserver.conf', "jruby-puppet.server-#{dir}-dir")).with_ensure('absent') }
          end
        end

        context 'with ca_status_whitelist' do
          let(:params) { { ca_status_whitelist: ['ca.example.com'] } }

          it {
            is_expected.to contain_hocon_setting(hocon('ca.conf', 'certificate-authority.certificate-status.client-whitelist'))
              .with(value: ['ca.example.com'], type: 'array')
          }
          it { is_expected.to contain_hocon_setting(hocon('ca.conf', 'certificate-authority.certificate-status.authorization-required')).with_value(true) }
        end

        context "with ca_status_whitelist => 'absent'" do
          let(:params) { { ca_status_whitelist: 'absent' } }

          it { is_expected.to contain_hocon_setting(hocon('ca.conf', 'certificate-authority.certificate-status')).with_ensure('absent') }
        end
      end

      describe 'webserver.conf' do
        context "with masterport => 'absent'" do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(single_server)) }
          let(:params) { { masterport: 'absent' } }

          # Only the puppet.conf setting goes; the server keeps its port
          it { is_expected.to contain_pupmod__conf('master_masterport').with_ensure('absent') }
          it { is_expected.to have_hocon_setting_resource_count(0) }
        end

        context 'with a non-default confdir that puppetserver does not read yet' do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(named_servers)) }
          let(:params) { { confdir: '/srv/puppetserver/conf.d', ssl_protocols: ['TLSv1.2'] } }

          # The fact describes another conf.d, so it is ignored
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ssl-protocols')).with_path('/srv/puppetserver/conf.d/webserver.conf') }
          it { is_expected.not_to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.ssl-protocols')) }
        end

        context 'with a non-default confdir that puppetserver reads' do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(named_servers, '/srv/puppetserver/conf.d')) }
          let(:params) { { confdir: '/srv/puppetserver/conf.d', ssl_protocols: ['TLSv1.2'], ca_port: 8141 } }

          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.ssl-protocols')).with_path('/srv/puppetserver/conf.d/webserver.conf') }
          # Already named servers, so the base server isn't rewritten
          it { is_expected.not_to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.ssl-host')) }
          it { is_expected.not_to contain_hocon_setting(hocon('webserver.conf', 'webserver.ssl-host')) }
        end

        context "with admin_api_mountpoint => 'absent'" do
          let(:params) { { admin_api_mountpoint: 'absent' } }

          it { is_expected.to compile.and_raise_error(%r{admin_api_mountpoint cannot be removed}) }
        end

        context 'without ca_port, on the package layout' do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(single_server)) }
          let(:params) { { masterport: 8150, bind_address: '10.0.0.1', ssl_protocols: ['TLSv1.1', 'TLSv1.2'] } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ssl-port')).with(ensure: 'present', value: 8150) }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ssl-host')).with_value('10.0.0.1') }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ssl-protocols')).with_value('TLSv1.1,TLSv1.2') }
          it { is_expected.not_to contain_hocon_setting(hocon('webserver.conf', 'webserver.client-auth')) }
          it { is_expected.not_to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.ssl-port')) }
          it { is_expected.not_to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca')) }
          it { is_expected.not_to contain_hocon_setting(hocon('web-routes.conf', ca_route)) }
        end

        context 'without any webserver settings' do
          it { expect(hocon_titles(%r{webserver})).to be_empty }
        end

        context 'with server_webserver_options on the package layout' do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(single_server)) }
          let(:params) { { server_webserver_options: { 'idle-timeout-milliseconds' => 60_000, 'request-header-max-size' => 'absent' } } }

          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.idle-timeout-milliseconds')).with_value(60_000) }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.request-header-max-size')).with_ensure('absent') }
        end

        shared_examples 'a CA on its own port' do |moved|
          it { is_expected.to compile.with_all_deps }

          moved.each do |key, value|
            it { is_expected.to contain_hocon_setting(hocon('webserver.conf', "webserver.#{key}")).with_ensure('absent') }

            next if key == 'client-auth'

            it { is_expected.to contain_hocon_setting(hocon('webserver.conf', "webserver.base.#{key}")).with(ensure: 'present', value: value) }
          end

          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.default-server')).with_value(true) }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.client-auth')).with_value('need') }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.ssl-port')).with_value(8141) }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.client-auth')).with_value('want') }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.ssl-crl-path')).with_value('/etc/puppetlabs/puppet/ssl/crl.pem') }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.ssl-ca-cert')).with_value('/etc/puppetlabs/puppet/ssl/certs/ca.pem') }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.ssl-cert')).with_value("/etc/puppetlabs/puppet/ssl/certs/#{fqdn}.pem") }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.ssl-key')).with_value("/etc/puppetlabs/puppet/ssl/private_keys/#{fqdn}.pem") }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.access-log-config')).with_value('/etc/puppetlabs/puppetserver/request-logging.xml') }
          it { is_expected.not_to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.default-server')) }
          it {
            is_expected.to contain_hocon_setting(hocon('web-routes.conf', ca_route))
              .with_value({ 'default' => { 'route' => '/puppet-ca', 'server' => 'ca' } })
          }
        end

        context 'with a CA port on the package layout' do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(single_server)) }
          let(:params) { { ca_port: 8141 } }

          it_behaves_like 'a CA on its own port', {
            'access-log-config' => '/etc/puppetlabs/puppetserver/request-logging.xml',
            'client-auth'       => 'want',
            'ssl-host'          => '0.0.0.0',
            'ssl-port'          => 8140,
          }

          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.ssl-host')).with_value('0.0.0.0') }
        end

        context 'with a CA port before puppetserver is installed' do
          let(:facts) { os_facts.reject { |k, _| k.to_s == 'puppetserver_webserver' } }
          let(:params) { { ca_port: 8141 } }

          it_behaves_like 'a CA on its own port', {
            'access-log-config' => '/etc/puppetlabs/puppetserver/request-logging.xml',
            'client-auth'       => 'want',
            'ssl-host'          => '0.0.0.0',
            'ssl-port'          => 8140,
          }
        end

        context 'with a CA port on an administrator-customized single server' do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(single_server.merge('ssl-port' => 8150, 'ssl-host' => '10.2.2.2'))) }
          let(:params) { { ca_port: 8141 } }

          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.ssl-port')).with_value(8150) }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.ssl-host')).with_value('10.2.2.2') }
          # The CA listens on the main server's address
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.ssl-host')).with_value('10.2.2.2') }
        end

        context 'with a CA port and bind addresses' do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(single_server)) }

          context 'with bind_address' do
            let(:params) { { ca_port: 8141, bind_address: '10.3.3.3' } }

            it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.ssl-host')).with_value('10.3.3.3') }
            it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.ssl-host')).with_value('10.3.3.3') }
          end

          context 'with bind_address and ca_bind_address' do
            let(:params) { { ca_port: 8141, bind_address: '10.3.3.3', ca_bind_address: '10.4.4.4' } }

            it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.ssl-host')).with_value('10.4.4.4') }
          end
        end

        context 'with a CA port on named servers' do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(named_servers)) }
          let(:params) { { ca_port: 8141, ssl_protocols: ['TLSv1.2'], ca_webserver_options: { 'idle-timeout-milliseconds' => '30000' } } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.not_to contain_hocon_setting(hocon('webserver.conf', 'webserver.ssl-port')) }
          it { is_expected.not_to contain_hocon_setting(hocon('webserver.conf', 'webserver.ssl-host')) }
          it { is_expected.not_to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.ssl-port')) }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.ssl-protocols')).with_value('TLSv1.2') }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.ssl-protocols')).with_value('TLSv1.2') }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.ssl-host')).with_value('10.1.1.1') }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.idle-timeout-milliseconds')).with_value('30000') }
        end

        context 'with settings on named servers and no CA port' do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(named_servers)) }
          let(:params) { { masterport: 8140 } }

          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.ssl-port')).with_value(8140) }
          it { is_expected.not_to contain_hocon_setting(hocon('webserver.conf', 'webserver.ssl-port')) }
          it { expect(hocon_titles(%r{webserver\.ca})).to be_empty }
          it { is_expected.not_to contain_hocon_setting(hocon('web-routes.conf', ca_route)) }
        end

        shared_examples 'a CA on the main port' do
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca')).with_ensure('absent') }
          it { is_expected.to contain_hocon_setting(hocon('web-routes.conf', ca_route)).with_value('/puppet-ca') }
        end

        context 'with ca_port equal to masterport on named servers' do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(named_servers)) }
          let(:params) { { ca_port: 8140, masterport: 8140 } }

          it_behaves_like 'a CA on the main port'
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.client-auth')).with_value('want') }
        end

        context 'with ca_port equal to the current port on the package layout' do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(single_server)) }
          let(:params) { { ca_port: 8140 } }

          it_behaves_like 'a CA on the main port'
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.client-auth')).with_value('want') }
          it { is_expected.not_to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.client-auth')) }
        end

        context 'with enable_ca => false' do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(named_servers)) }
          let(:params) { { ca_port: 8141, enable_ca: false } }

          it_behaves_like 'a CA on the main port'
          # Without a CA, the main server requires client certificates, as in 12.x
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.client-auth')).with_value('need') }
        end

        context "with ca_port => 'absent' on named servers" do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(named_servers)) }
          let(:params) { { ca_port: 'absent' } }

          # Only the puppet.conf setting goes; the CA keeps its own server
          it { is_expected.to contain_pupmod__conf('master_ca_port').with_ensure('absent') }
          it { expect(hocon_titles(%r{webserver\.ca})).to be_empty }
          it { is_expected.not_to contain_hocon_setting(hocon('web-routes.conf', ca_route)) }
        end

        context 'with enable_ca => false on the package layout' do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(single_server)) }
          let(:params) { { enable_ca: false } }

          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.client-auth')).with_value('need') }
        end

        context 'with enable_master => true and a CA port' do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(named_servers)) }
          let(:params) { { ca_port: 8141, enable_master: true } }

          # A default-server left on the CA by an earlier enable_master => false is removed
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.default-server')).with_ensure('absent') }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.default-server')).with_value(true) }
        end

        context 'on a CA-only server' do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact('ca' => { 'ssl-port' => 8141, 'default-server' => true })) }

          context 'with nothing set' do
            it { expect(hocon_titles(%r{webserver\.conf})).to be_empty }
          end

          context 'with only ssl_protocols' do
            let(:params) { { ssl_protocols: ['TLSv1.2'] } }

            # No main server is created
            it { expect(hocon_titles(%r{webserver\.base})).to be_empty }
            # The CA is the only server, so the setting goes there
            it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.ssl-protocols')).with_value('TLSv1.2') }
          end

          context 'with enable_master => true' do
            let(:params) { { enable_master: true } }

            it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.default-server')).with_value(true) }
          end
        end

        context 'on named servers with enable_master unset' do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(named_servers)) }

          context 'with nothing set' do
            it { expect(hocon_titles(%r{webserver\.conf})).to be_empty }
          end

          context 'with only ssl_protocols' do
            let(:params) { { ssl_protocols: ['TLSv1.2'] } }

            it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.ssl-protocols')).with_value('TLSv1.2') }
            it { is_expected.not_to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.default-server')) }
            # The CA on its own port gets it too, without ca_port
            it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.ssl-protocols')).with_value('TLSv1.2') }
            it { is_expected.not_to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.ssl-port')) }
            it { is_expected.not_to contain_hocon_setting(hocon('web-routes.conf', ca_route)) }
          end

          context 'with ssl_cipher_suites, ca_bind_address and ca_webserver_options' do
            let(:params) do
              {
                ssl_cipher_suites: ['TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'],
                ca_bind_address: '10.5.5.5',
                ca_webserver_options: { 'idle-timeout-milliseconds' => '30000' },
              }
            end

            it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.cipher-suites')).with_value('TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384') }
            it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.ssl-host')).with_value('10.5.5.5') }
            it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.idle-timeout-milliseconds')).with_value('30000') }
          end
        end

        context 'on the package layout with ca_bind_address and no CA port' do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(single_server)) }
          let(:params) { { ca_bind_address: '10.5.5.5', ssl_protocols: ['TLSv1.2'] } }

          # There is no ca server to write to
          it { expect(hocon_titles(%r{webserver\.ca})).to be_empty }
        end

        context 'with enable_master => false and a CA port' do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(named_servers)) }
          let(:params) { { ca_port: 8141, enable_master: false } }

          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.base')).with_ensure('absent') }
          it { is_expected.not_to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.client-auth')) }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ca.default-server')).with_value(true) }
        end

        context 'with extra_webserver_sections on the package layout' do
          let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(single_server)) }
          let(:params) { { extra_webserver_sections: { 'extra' => { 'ssl-port' => 8200, 'ssl-host' => 'absent' } } } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.ssl-port')).with_ensure('absent') }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.ssl-port')).with_value(8140) }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.extra.ssl-port')).with_value(8200) }
          it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.extra.ssl-host')).with_ensure('absent') }
        end
      end

      describe 'the main port' do
        let(:facts) { os_facts.merge(puppetserver_webserver: webserver_fact(single_server.merge('ssl-port' => 8150))) }
        let(:params) { { firewall: true, ca_port: 8141 } }
        let(:hieradata) { 'master_helper_scripts' }

        # Without masterport, every user of the port takes it from webserver.conf
        it { is_expected.to contain_hocon_setting(hocon('webserver.conf', 'webserver.base.ssl-port')).with_value(8150) }
        it { is_expected.to contain_iptables__listen__tcp_stateful('allow_puppet').with_dports(8150) }
        it { is_expected.to contain_file('/usr/local/sbin/puppetserver_clear_environment_cache').with_content(%r{:8150/}) }
      end

      describe 'web-routes.conf admin route' do
        context 'with a leading slash' do
          let(:params) { { admin_api_mountpoint: '/admin' } }

          it { is_expected.to contain_hocon_setting(hocon('web-routes.conf', admin_route)).with_value('/admin') }
        end

        context 'without a leading slash' do
          let(:params) { { admin_api_mountpoint: 'admin' } }

          it { is_expected.to contain_hocon_setting(hocon('web-routes.conf', admin_route)).with_value('/admin') }
        end
      end

      describe 'services.d/ca.cfg' do
        let(:ca_cfg) { 'pupmod::master ca.cfg certificate-authority-service' }

        context 'with enable_ca => true' do
          let(:params) { { enable_ca: true } }

          it {
            is_expected.to contain_file_line(ca_cfg).with(
              path: '/etc/puppetlabs/puppetserver/services.d/ca.cfg',
              line: 'puppetlabs.services.ca.certificate-authority-service/certificate-authority-service',
              match: '^\s*puppetlabs\.services\.ca\.certificate-authority-(disabled-)?service/',
            ).that_requires('Class[pupmod::master::install]')
          }
        end

        context 'with enable_ca => false' do
          let(:params) { { enable_ca: false } }

          it { is_expected.to contain_file_line(ca_cfg).with_line('puppetlabs.services.ca.certificate-authority-disabled-service/certificate-authority-disabled-service') }
        end

        context 'without enable_ca' do
          it { is_expected.not_to contain_file_line(ca_cfg) }
        end
      end

      describe 'logback.xml' do
        let(:logback) { { incl: '/etc/puppetlabs/puppetserver/logback.xml', lens: 'Xml.lns', context: '/files/etc/puppetlabs/puppetserver/logback.xml/configuration' } }

        context 'with log_level' do
          let(:params) { { log_level: 'INFO' } }

          it {
            is_expected.to contain_augeas('pupmod::master logback.xml log_level').with(logback).with_changes(
              [
                "set logger[#attribute/name='org.eclipse.jetty']/#attribute/level INFO",
                'set root/#attribute/level INFO',
              ],
            ).that_requires('Class[pupmod::master::install]').that_notifies('Class[pupmod::master::service]')
          }
        end

        shared_examples 'syslog on' do
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_augeas('pupmod::master logback.xml SYSLOG appender').with(logback).with_onlyif("match root[count(../appender[#attribute/name='SYSLOG']) = 0] size == 1") }
          it { is_expected.to contain_augeas('pupmod::master logback.xml SYSLOG').that_requires('Augeas[pupmod::master logback.xml SYSLOG appender]') }
          it {
            expect(catalogue.resource('Augeas', 'pupmod::master logback.xml SYSLOG')[:changes]).to include(
              "set appender[#attribute/name='SYSLOG']/facility/#text LOCAL6",
              "set appender[#attribute/name='SYSLOG']/suffixPattern/#text '%logger[%thread]: %msg'",
              "set root/appender-ref[#attribute/ref='SYSLOG']/#attribute/ref SYSLOG",
            )
          }
        end

        shared_examples 'syslog off' do
          it { is_expected.not_to contain_augeas('pupmod::master logback.xml SYSLOG appender') }
          it { is_expected.to contain_augeas('pupmod::master logback.xml SYSLOG').with_changes(["rm root/appender-ref[#attribute/ref='SYSLOG']"]) }
        end

        context 'with syslog => true' do
          let(:params) { { syslog: true } }

          it_behaves_like 'syslog on'
        end

        context 'with simp_options::syslog => true' do
          let(:hieradata) { 'master_syslog_true' }

          it_behaves_like 'syslog on'
        end

        context 'with syslog => false' do
          let(:params) { { syslog: false } }

          it_behaves_like 'syslog off'
        end

        context 'with simp_options::syslog => false' do
          let(:hieradata) { 'master_syslog_false' }

          it_behaves_like 'syslog off'
        end

        context 'with log_to_file => true' do
          let(:params) { { log_to_file: true } }

          it { is_expected.to contain_augeas('pupmod::master logback.xml F1').with_changes(["set root/appender-ref[#attribute/ref='F1']/#attribute/ref F1"]) }
        end

        context 'with log_to_file => false' do
          let(:params) { { log_to_file: false } }

          it { is_expected.to contain_augeas('pupmod::master logback.xml F1').with_changes(["rm root/appender-ref[#attribute/ref='F1']"]) }
        end
      end

      describe 'os-settings.conf' do
        context 'with ruby_load_path' do
          let(:params) { { ruby_load_path: '/usr/share/ruby' } }

          it {
            is_expected.to contain_hocon_setting(hocon('os-settings.conf', 'os-settings.ruby-load-path')).with(
              ensure: 'present',
              path: '/etc/puppetlabs/puppetserver/conf.d/os-settings.conf',
              value: ['/usr/share/ruby'],
              type: 'array',
            ).that_requires('Class[pupmod::master::install]')
          }
          it { is_expected.not_to contain_file('/etc/puppetlabs/puppetserver/conf.d/os-settings.conf') }
        end

        context "with ruby_load_path => 'absent'" do
          let(:params) { { ruby_load_path: 'absent' } }

          it { is_expected.to contain_hocon_setting(hocon('os-settings.conf', 'os-settings.ruby-load-path')).with_ensure('absent') }
          it { is_expected.not_to contain_file('/etc/puppetlabs/puppetserver/conf.d/os-settings.conf') }
        end
      end
    end
  end
end
