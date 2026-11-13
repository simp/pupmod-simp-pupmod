# frozen_string_literal: true

require 'spec_helper'
require 'yaml'

# Tests the `simp:defaults` Sicura Compliance Engine profile end to end: with
# `compliance_engine::enforcement: [simp:defaults]` in Hiera, the otherwise
# package-only `include pupmod` must reproduce what the module managed by
# default before 13.0.0.
#
# The "bare include is a no-op" regression specs live in init_spec.rb and
# master_spec.rb and are intentionally left alone -- they guard the safe
# default when the profile is NOT enforced.
describe 'pupmod' do
  def self.profile_dir
    File.expand_path('../../SIMP/compliance_profiles', __dir__)
  end

  # Settings pupmod wrote to puppet.conf before 13.0.0, by resource title,
  # with the section and value
  PROFILE_PUPPET_CONF = {
    'agent_daemonize' => ['agent', 'daemonize', false],
    'splay' => ['main', 'splay', false],
    'syslogfacility' => ['main', 'syslogfacility', 'local6'],
    'srv_domain' => ['main', 'srv_domain', 'example.com'],
    'certname' => ['main', 'certname', 'profile.example.com'],
    'classfile' => ['main', 'classfile', '$vardir/classes.txt'],
    'runinterval' => ['main', 'runinterval', 1800],
    'digest_algorithm' => ['main', 'digest_algorithm', 'sha256'],
    'confdir' => ['main', 'confdir', '/etc/puppetlabs/puppet'],
    'vardir' => ['main', 'vardir', '/opt/puppetlabs/puppet/cache'],
    'logdir' => ['main', 'logdir', '/var/log/puppetlabs/puppet'],
    'rundir' => ['main', 'rundir', '/var/run/puppetlabs'],
    'ssldir' => ['main', 'ssldir', '/etc/puppetlabs/puppet/ssl'],
    'masterport' => ['main', 'masterport', 8140],
    'report' => ['agent', 'report', false],
    'master_environmentpath' => ['server', 'environmentpath', '/etc/puppetlabs/code/environments'],
    'master_daemonize' => ['server', 'daemonize', true],
    'master_masterport' => ['server', 'masterport', 8140],
    'ca_ttl' => ['server', 'ca_ttl', '10y'],
    'freeze_main' => ['main', 'freeze_main', false],
    'strict_hostname_checking' => ['main', 'strict_hostname_checking', true],
  }.freeze

  # puppetserver.conf, ca.conf and product.conf settings, with their values
  PROFILE_HOCON = {
    'puppetserver.conf' => {
      'jruby-puppet.server-conf-dir' => '/etc/puppetlabs/puppet',
      'jruby-puppet.server-code-dir' => '/etc/puppetlabs/code',
      'jruby-puppet.server-var-dir' => '/opt/puppetlabs/server/data/puppetserver',
      'jruby-puppet.server-run-dir' => '/var/run/puppetlabs/puppetserver',
      'jruby-puppet.server-log-dir' => '/var/log/puppetlabs/puppetserver',
      'jruby-puppet.max-requests-per-instance' => 100_000,
      'jruby-puppet.borrow-timeout' => 1_200_000,
      'jruby-puppet.environment-class-cache-enabled' => true,
      'jruby-puppet.compile-mode' => 'off',
      'jruby-puppet.use-legacy-auth-conf' => false,
      'jruby-puppet.max-queued-requests' => 10,
      'jruby-puppet.max-retry-delay' => 1800,
      'jruby-puppet.profiling-mode' => 'off',
      'jruby-puppet.profiler-output-file' => '/opt/puppetlabs/server/data/puppetserver/server_jruby_profiling',
      'http-client.ssl-protocols' => ['TLSv1.3', 'TLSv1.2'],
      'profiler.enabled' => false,
      'puppet-admin.client-whitelist' => ['profile.example.com'],
    },
    'ca.conf' => {
      'certificate-authority.allow-authorization-extensions' => false,
      'certificate-authority.allow-subject-alt-names' => false,
      'certificate-authority.certificate-status.client-whitelist' => ['profile.example.com'],
      'certificate-authority.certificate-status.authorization-required' => true,
    },
    'product.conf' => {
      'product.check-for-updates' => false,
    },
  }.freeze

  PROFILE_SYSCONFIG = {
    'JAVA_BIN' => '"/usr/bin/java"',
    'INSTALL_DIR' => '"/opt/puppetlabs/server/apps/puppetserver"',
    'CONFIG' => '"/etc/puppetlabs/puppetserver/conf.d"',
    'BOOTSTRAP_CONFIG' => '"/etc/puppetlabs/puppetserver/services.d/,/opt/puppetlabs/server/apps/puppetserver/config/services.d/"',
    'SERVICE_STOP_RETRIES' => 60,
    'START_TIMEOUT' => 120,
  }.freeze

  let(:hiera_config) do
    File.expand_path('../fixtures/hieradata/hiera_compliance_engine.yaml', __dir__)
  end

  # ---------------------------------------------------------------------------
  # Profile/check data integrity. No catalogue compilation.
  # ---------------------------------------------------------------------------
  context 'profile data' do
    let(:checks) { YAML.safe_load_file(File.join(self.class.profile_dir, 'checks.yaml'))['checks'] }
    let(:profile) { YAML.safe_load_file(File.join(self.class.profile_dir, 'profile-simp_defaults.yaml'))['profiles']['simp:defaults'] }

    it 'lists exactly the defined checks (no orphans, none missing)' do
      expect(profile['checks'].keys.sort).to eq(checks.keys.sort)
    end

    it 'names checks simp:defaults.pupmod.<class path>.<param>[.<discriminator>]' do
      bad = checks.reject do |id, check|
        id.start_with?("simp:defaults.#{check['settings']['parameter'].tr(':', '.').squeeze('.')}")
      end
      expect(bad.keys).to eq([])
    end

    it 'only manages pupmod:: parameters' do
      params = checks.values.map { |c| c['settings']['parameter'] }
      expect(params).to all(start_with('pupmod::'))
    end

    # A check naming a parameter that does not exist binds nothing and fails
    # silently, which is the failure mode this test exists to prevent.
    it 'names only parameters the pupmod classes actually declare' do
      missing = checks.values.map { |c| c['settings']['parameter'] }.uniq.reject do |param|
        klass, _, name = param.rpartition('::')
        manifest = (klass == 'pupmod') ? 'init' : klass.delete_prefix('pupmod::').gsub('::', '/')
        src = File.read(File.expand_path("../../manifests/#{manifest}.pp", __dir__))
        src.match?(%r{^\s+\S.*\$#{Regexp.escape(name)}(\s+=|,|\s*$)})
      end
      expect(missing).to eq([])
    end

    # These follow simp_options; a check would override a site's value
    it 'restores no parameter that defaults to a simp_options lookup' do
      params = checks.values.map { |c| c['settings']['parameter'] }
      expect(params).not_to include(
        'pupmod::ca_server', 'pupmod::ca_port', 'pupmod::puppet_server', 'pupmod::haveged',
        'pupmod::fips', 'pupmod::firewall', 'pupmod::master::ca_port', 'pupmod::master::firewall',
        'pupmod::master::auditd', 'pupmod::master::syslog', 'pupmod::master::trusted_nets'
      )
    end
  end

  # Representative releases: the newest (whose data the defaults describe) and
  # the oldest (whose module data overrides them)
  on_supported_os.select { |os, _| os.match?(%r{^redhat-(8|10)-}) }.each do |os, os_facts|
    context "on #{os}" do
      let(:node) { 'profile.example.com' }
      let(:base_facts) do
        os_facts.merge(
          networking: os_facts[:networking].merge(fqdn: 'profile.example.com', domain: 'example.com'),
          fips_enabled: false,
        )
      end
      let(:params) { { enable_puppet_master: true } }

      # -----------------------------------------------------------------------
      # Enforced, no overrides: reproduces the pre-13.0.0 catalogue.
      # -----------------------------------------------------------------------
      context 'when enforcing simp:defaults' do
        let(:facts) { base_facts }
        let(:hieradata) { 'simp_defaults_enforced' }

        it { is_expected.to compile.with_all_deps }

        it 'schedules agent runs with the timer and stops the daemon' do
          is_expected.to contain_class('pupmod::agent::cron')
          is_expected.to contain_systemd__timer('puppet_agent.timer')
          is_expected.to contain_service('puppet').with(ensure: 'stopped', enable: false)
        end

        it 'writes the pre-13.0.0 puppet.conf settings' do
          PROFILE_PUPPET_CONF.each do |title, (section, setting, value)|
            is_expected.to contain_ini_setting("pupmod_#{title}").with(
              ensure: 'present', section: section, setting: setting, value: value,
            )
          end
        end

        it 'writes the CA key length for the FIPS mode' do
          is_expected.to contain_ini_setting('pupmod_keylength').with(section: 'server', value: 4096)
        end

        it 'restores the agent sysconfig, log purging and SELinux boolean' do
          is_expected.to contain_file_line('pupmod PUPPET_EXTRA_OPTS').with_line("PUPPET_EXTRA_OPTS='--daemonize'")
          is_expected.to contain_systemd__tmpfile('puppet_purge_puppet_service_logs.conf')
            .with_content('e /var/log/puppetlabs/puppet* - - - 4w')
          if os_facts.dig(:os, :selinux, :enabled)
            is_expected.to contain_exec('Set puppetagent_manage_all_files seboolean')
              .with_command('/usr/sbin/setsebool -P puppetagent_manage_all_files on')
          end
        end

        it 'owns the puppet directories with the puppet group' do
          is_expected.to contain_group('puppet')
          is_expected.to contain_file('/etc/puppetlabs/puppet').with(group: 'puppet', mode: '0640')
          is_expected.to contain_file('/etc/puppetlabs/puppet/puppet.conf').with(group: 'puppet', mode: '0640')
          is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d').with(group: 'puppet', mode: '0640')
          is_expected.to contain_file('/etc/puppetlabs/code/environments').with(group: 'puppet', recurse: true)
          is_expected.to contain_user('puppet').with(gid: 'puppet', home: '/opt/puppetlabs/server/data/puppetserver')
        end

        it 'installs, runs and supports puppetserver as before' do
          is_expected.to contain_package('openvox-server')
          is_expected.to contain_package("https://yum.voxpupuli.org/openvox8-release-el-#{os_facts[:os][:release][:major]}.noarch.rpm")
          is_expected.to contain_service('puppetserver').with(ensure: 'running', enable: true)
          is_expected.to contain_exec('puppetserver_reload')
          is_expected.to contain_file('/usr/local/sbin/puppetserver_clear_environment_cache')
          is_expected.to contain_file('/usr/local/sbin/simp_generate_types')
          is_expected.to contain_systemd__unit_file('simp_generate_types.path')
          is_expected.to contain_systemd__tmpfile('purge_puppetserver_reports.conf').with_ensure('present')
        end

        it 'writes the pre-13.0.0 puppetserver HOCON settings' do
          PROFILE_HOCON.each do |file, settings|
            settings.each do |setting, value|
              is_expected.to contain_hocon_setting("pupmod::master #{file} #{setting}").with(ensure: 'present', value: value)
            end
          end
          is_expected.to contain_hocon_setting('pupmod::master puppetserver.conf jruby-puppet.max-active-instances')
            .with_value(%r{\A[1-9]\d*\z})
          is_expected.to contain_hocon_setting('pupmod::master puppetserver.conf jruby-puppet.master-conf-dir')
            .with_ensure('absent')
          is_expected.to contain_file_line('pupmod::master ca.cfg certificate-authority-service')
            .with_line('puppetlabs.services.ca.certificate-authority-service/certificate-authority-service')
        end

        it 'keeps the single-server webserver.conf when the CA port is unknown' do
          is_expected.to contain_hocon_setting('pupmod::master webserver.conf webserver.ssl-port').with_value(8140)
          is_expected.to contain_hocon_setting('pupmod::master webserver.conf webserver.ssl-host').with_value('0.0.0.0')
          is_expected.not_to contain_hocon_setting('pupmod::master webserver.conf webserver.ca.ssl-port')
        end

        it 'allows TLS 1.3 and TLS 1.2 with FIPS-approved TLS 1.3 cipher suites' do
          is_expected.to contain_hocon_setting('pupmod::master webserver.conf webserver.ssl-protocols').with_value('TLSv1.3,TLSv1.2')
          suites = catalogue.resource('Hocon_setting', 'pupmod::master webserver.conf webserver.cipher-suites')[:value].split(',')
          expect(suites).to include('TLS_AES_256_GCM_SHA384', 'TLS_AES_128_GCM_SHA256')
          expect(suites).not_to include('TLS_CHACHA20_POLY1305_SHA256')
          expect(suites).to include('TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384')
          is_expected.to contain_hocon_setting('pupmod::master puppetserver.conf http-client.cipher-suites').with_value(suites)
        end

        it 'writes the pre-13.0.0 JVM settings' do
          PROFILE_SYSCONFIG.each do |setting, value|
            is_expected.to contain_ini_setting("pupmod::master::sysconfig #{setting}").with(ensure: 'present', value: value)
          end
          ['JAVA_ARGS', 'JAVA_ARGS_CLI'].each do |setting|
            is_expected.to contain_ini_subsetting("pupmod::master::sysconfig #{setting} -Xmx").with_value(%r{\A\d+m\z})
            is_expected.to contain_ini_subsetting("pupmod::master::sysconfig #{setting} -Dcom.redhat.fips").with_value('=false')
            is_expected.to contain_ini_subsetting("pupmod::master::sysconfig #{setting} -Djava.io.tmpdir")
              .with_value('=/opt/puppetlabs/puppet/cache/pserver_tmp')
            is_expected.to contain_ini_subsetting("pupmod::master::sysconfig #{setting} -XX:+UseCodeCacheFlushing").with_ensure('present')
          end
          is_expected.to contain_file('/opt/puppetlabs/puppet/cache/pserver_tmp').with_ensure('directory')
        end

        it 'sets the logging as before' do
          is_expected.to contain_augeas('pupmod::master logback.xml log_level').with_changes(
            [
              "set logger[#attribute/name='org.eclipse.jetty']/#attribute/level WARN",
              'set root/#attribute/level WARN',
            ],
          )
          is_expected.to contain_augeas('pupmod::master logback.xml F1').with_changes(["rm root/appender-ref[#attribute/ref='F1']"])
        end

        it 'leaves the simp_options-driven settings alone' do
          is_expected.not_to contain_ini_setting('pupmod_server')
          is_expected.not_to contain_ini_setting('pupmod_ca_server')
          is_expected.not_to contain_ini_setting('pupmod_ca_port')
          is_expected.not_to contain_class('iptables')
          is_expected.not_to contain_class('auditd')
        end
      end

      context 'when enforcing simp:defaults with FIPS enabled' do
        let(:facts) { base_facts.merge(fips_enabled: true) }
        let(:hieradata) { 'simp_defaults_enforced' }

        it { is_expected.to contain_ini_setting('pupmod_keylength').with_value(2048) }
      end

      # -----------------------------------------------------------------------
      # A SIMP site sets simp_options; together with the profile that is the
      # complete pre-13.0.0 catalogue, including the CA on its own port.
      # -----------------------------------------------------------------------
      context 'when enforcing simp:defaults on a SIMP site' do
        let(:facts) { base_facts }
        let(:hieradata) { 'simp_defaults_simp_options' }

        it { is_expected.to compile.with_all_deps }

        it 'points the agent at the SIMP servers' do
          is_expected.to contain_ini_setting('pupmod_server').with_value('puppet.example.com')
          is_expected.to contain_ini_setting('pupmod_server_list').with_ensure('absent')
          is_expected.to contain_ini_setting('pupmod_ca_server').with_value('puppet.example.com')
          is_expected.to contain_ini_setting('pupmod_ca_port').with_value(8141)
          is_expected.to contain_ini_setting('pupmod_master_ca_port').with(section: 'server', value: 8141)
        end

        it 'runs the CA as its own server' do
          is_expected.to contain_hocon_setting('pupmod::master webserver.conf webserver.ssl-port').with_ensure('absent')
          is_expected.to contain_hocon_setting('pupmod::master webserver.conf webserver.base.ssl-port').with_value(8140)
          is_expected.to contain_hocon_setting('pupmod::master webserver.conf webserver.base.client-auth').with_value('need')
          is_expected.to contain_hocon_setting('pupmod::master webserver.conf webserver.base.default-server').with_value(true)
          is_expected.to contain_hocon_setting('pupmod::master webserver.conf webserver.ca.ssl-port').with_value(8141)
          is_expected.to contain_hocon_setting('pupmod::master webserver.conf webserver.ca.client-auth').with_value('want')
          is_expected.to contain_hocon_setting('pupmod::master webserver.conf webserver.ca.ssl-cert')
            .with_value('/etc/puppetlabs/puppet/ssl/certs/profile.example.com.pem')
          is_expected.to contain_hocon_setting(
            'pupmod::master web-routes.conf web-router-service."puppetlabs.services.ca.certificate-authority-service/certificate-authority-service"',
          ).with_value('default' => { 'route' => '/puppet-ca', 'server' => 'ca' })
        end

        it 'opens the firewall, audits and logs to syslog' do
          is_expected.to contain_iptables__listen__tcp_stateful('allow_puppet').with(dports: 8140, trusted_nets: ['10.0.0.0/8'])
          is_expected.to contain_iptables__listen__tcp_stateful('allow_puppetca').with(dports: 8141, trusted_nets: ['10.0.0.0/8'])
          is_expected.to contain_auditd__rule('puppet_master')
          is_expected.to contain_augeas('pupmod::master logback.xml SYSLOG appender')
          is_expected.to contain_augeas('pupmod::master logback.xml SYSLOG')
        end
      end

      # -----------------------------------------------------------------------
      # Enforced + explicit site Hiera: the site wins. These toggles are the
      # destructive and disruptive ones a site would turn back off.
      # -----------------------------------------------------------------------
      context 'when enforcing simp:defaults with site overrides' do
        let(:facts) { base_facts }
        let(:hieradata) { 'simp_defaults_with_override' }

        it { is_expected.to compile.with_all_deps }

        it 'lets site Hiera beat the profile' do
          is_expected.to contain_systemd__tmpfile('puppet_purge_puppet_service_logs.conf').with_ensure('absent')
          is_expected.to contain_systemd__tmpfile('purge_puppetserver_reports.conf').with_ensure('absent')
          is_expected.to contain_service('puppetserver').with(ensure: 'stopped', enable: true)
        end
      end

      context 'without enforcement' do
        let(:facts) { base_facts }

        it 'installs only the packages' do
          types = catalogue.resources.map(&:type).uniq - ['Class', 'Stage', 'Node', 'Pupmod::Pass_two']
          expect(types).to contain_exactly('Package')
        end
      end
    end
  end
end
