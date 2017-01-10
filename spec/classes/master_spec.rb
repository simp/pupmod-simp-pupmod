require 'spec_helper'

describe 'pupmod::master' do
  before :all do
    @extras = { :puppet_settings => {
      'master' => {
        'rest_authconfig' => '/etc/puppetlabs/puppet/authconf.conf'
    }}}
  end
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts){ @extras.merge(os_facts) }

      describe "with default parameters" do
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

        it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/services.d/ca.cfg').with({
          'ensure'  => 'file',
          'owner'   => 'root',
          'group'   => 'puppet',
          'mode'    => '0640',
          'content' => %q{# This file managed by Puppet
# Any changes will be removed on the next run
puppetlabs.services.ca.certificate-authority-service/certificate-authority-service
},
          'require' => 'Package[puppetserver]',
          'notify'  => 'Service[puppetserver]'
        }) }

        it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/logback.xml').with({
          'ensure'  => 'file',
          'owner'   => 'root',
          'group'   => 'puppet',
          'mode'    => '0640',
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
~,
          'require' => 'Package[puppetserver]',
          'notify'  => 'Service[puppetserver]'
        }) }

        it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d/ca.conf').with({
          'ensure'  => 'file',
          'owner'   => 'root',
          'group'   => 'puppet',
          'mode'    => '0640',
          'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run

# CA-related settings
certificate-authority: {

    # settings for the certificate_status HTTP endpoint
    certificate-status: {

        # this setting contains a list of client certnames who are whitelisted to
        # have access to the certificate_status endpoint.  Any requests made to
        # this endpoint that do not present a valid client cert mentioned in
        # this list will be denied access.
        client-whitelist: [foo.example.com]
        authorization-required: true
    }
}
~,
          'require' => 'Package[puppetserver]',
          'notify'  => 'Service[puppetserver]'
        }) }

        it { is_expected.to_not contain_file('/etc/puppetlabs/puppetserver/conf.d/os-settings.conf') }
        it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d/puppetserver.conf').with({
          'ensure'  => 'file',
          'owner'   => 'root',
          'group'   => 'puppet',
          'mode'    => '0640',
          'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run

# configuration for the JRuby interpreters
jruby-puppet: {
    # Where the puppet-agent dependency places puppet, facter, etc...
    # Puppet server expects to load Puppet from this location
    ruby-load-path: [/opt/puppetlabs/puppet/lib/ruby/vendor_ruby]

    # This setting determines where JRuby will look for gems.  It is also
    # used by the `puppetserver gem` command line tool.
    gem-home: /opt/puppetlabs/server/data/puppetserver/jruby-gems

    # PLEASE NOTE: Use caution when modifying the below settings. Modifying
    # these settings will change the value of the corresponding Puppet settings
    # for Puppet Server, but not for the Puppet CLI tools. This likely will not
    # be a problem with master-var-dir, master-run-dir, or master-log-dir unless
    # some critical setting in puppet.conf is interpolating the value of one
    # of the corresponding settings, but it is important that any changes made to
    # master-conf-dir and master-code-dir are also made to the corresponding Puppet
    # settings when running the Puppet CLI tools. See
    # https://docs.puppetlabs.com/puppetserver/latest/puppet_conf_setting_diffs.html#overriding-puppet-settings-in-puppet-server
    # for more information.

    # (optional) path to puppet conf dir; if not specified, will use the puppet default
    master-conf-dir: /etc/puppetlabs/puppet

    # (optional) path to puppet code dir; if not specified, will use
    # /etc/puppetlabs/code
    master-code-dir: /etc/puppetlabs/code

    # (optional) path to puppet run dir; if not specified, will use
    # /var/run/puppetlabs/puppetserver
    master-run-dir: /var/run/puppetlabs/puppetserver

    # (optional) path to puppet log dir; if not specified, will use
    # /var/log/puppetlabs/puppetserver
    master-log-dir: /var/log/puppetlabs/puppetserver

    # (optional) path to puppet var dir; if not specified, will use the puppet default
    master-var-dir: /opt/puppetlabs/server/data/puppetserver

    # (optional) maximum number of JRuby instances to allow; defaults to <num-cpus>+2
    max-active-instances: 3

    # (optional) Authorize access to Puppet master endpoints via rules specified
    # in the legacy Puppet auth.conf file (if true or not specified) or via rules
    # specified in the Puppet Server HOCON-formatted auth.conf (if false).
    use-legacy-auth-conf: true
}

# settings related to HTTP client requests made by Puppet Server
http-client: {
    # A list of acceptable protocols for making HTTP requests
    ssl-protocols: [TLSv1,TLSv1.1,TLSv1.2]
}

# settings related to profiling the puppet Ruby code
profiler: {
    # enable or disable profiling for the Ruby code; defaults to 'false'.
    enabled: false
}

# Settings related to the puppet-admin HTTP API
puppet-admin: {
    client-whitelist: [foo.example.com]
}
~,
          'require' => 'Package[puppetserver]',
          'notify'  => 'Service[puppetserver]'
        }) }

        it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d/web-routes.conf').with({
          'ensure'  => 'file',
          'owner'   => 'root',
          'group'   => 'puppet',
          'mode'    => '0640',
          'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run
web-router-service: {
  "puppetlabs.services.ca.certificate-authority-service/certificate-authority-service": {
     default: {
       route: "/puppet-ca"
       server: "ca"
     }
  }

  "puppetlabs.trapperkeeper.services.status.status-service/status-service": "/status"
  "puppetlabs.services.master.master-service/master-service": "/puppet"
  "puppetlabs.services.legacy-routes.legacy-routes-service/legacy-routes-service": ""

  # This controls the mount point for the puppet admin API.
  "puppetlabs.services.puppet-admin.puppet-admin-service/puppet-admin-service": "/puppet-admin-api"
}
~,
          'require' => 'Package[puppetserver]',
          'notify'  => 'Service[puppetserver]'
        }) }

        it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d/webserver.conf').with({
          'ensure'  => 'file',
          'owner'   => 'root',
          'group'   => 'puppet',
          'mode'    => '0640',
          'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run
webserver: {
  base: {
    access-log-config: /etc/puppetlabs/puppetserver/request-logging.xml
    client-auth: need
    ssl-crl-path: /etc/puppetlabs/puppet/ssl/crl.pem
    ssl-ca-cert: /etc/puppetlabs/puppet/ssl/certs/ca.pem
    ssl-cert: /etc/puppetlabs/puppet/ssl/certs/foo.example.com.pem
    ssl-key: /etc/puppetlabs/puppet/ssl/private_keys/foo.example.com.pem
    ssl-host: 0.0.0.0
    ssl-port: 8140
    default-server: true
  }
  ca: {
    access-log-config: /etc/puppetlabs/puppetserver/request-logging.xml
    client-auth: want
    ssl-crl-path: /etc/puppetlabs/puppet/ssl/crl.pem
    ssl-ca-cert: /etc/puppetlabs/puppet/ssl/certs/ca.pem
    ssl-cert: /etc/puppetlabs/puppet/ssl/certs/foo.example.com.pem
    ssl-key: /etc/puppetlabs/puppet/ssl/private_keys/foo.example.com.pem
    ssl-host: 0.0.0.0
    ssl-port: 8141
  }
}
~,
          'require' => 'Package[puppetserver]',
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
        context 'with enable_ca => false' do
          let(:params) {{:enable_ca => false}}
          it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/services.d/ca.cfg').with({
            'ensure'  => 'file',
            'owner'   => 'root',
            'group'   => 'puppet',
            'mode'    => '0640',
            'content' => %q{# This file managed by Puppet
# Any changes will be removed on the next run
puppetlabs.services.ca.certificate-authority-disabled-service/certificate-authority-disabled-service
},
            'require' => 'Package[puppetserver]',
            'notify'  => 'Service[puppetserver]'
          }) }
        end

        context 'with syslog => true and log_to_file => true' do
          let(:params) {{:syslog => true, :log_to_file => true}}
          it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/logback.xml').with({
            'ensure'  => 'file',
            'owner'   => 'root',
            'group'   => 'puppet',
            'mode'    => '0640',
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
~,
          'require' => 'Package[puppetserver]',
          'notify'  => 'Service[puppetserver]'
        }) }
        end

        context 'with multiple entries in ca_status_whitelist' do
          let(:params) {{:ca_status_whitelist => ['1.2.3.4', '5.6.7.8']}}
          it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d/ca.conf').with({
            'ensure'  => 'file',
            'owner'   => 'root',
            'group'   => 'puppet',
            'mode'    => '0640',
            'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run

# CA-related settings
certificate-authority: {

    # settings for the certificate_status HTTP endpoint
    certificate-status: {

        # this setting contains a list of client certnames who are whitelisted to
        # have access to the certificate_status endpoint.  Any requests made to
        # this endpoint that do not present a valid client cert mentioned in
        # this list will be denied access.
        client-whitelist: [1.2.3.4,5.6.7.8]
        authorization-required: true
    }
}
~,
            'require' => 'Package[puppetserver]',
            'notify'  => 'Service[puppetserver]'
          }) }
        end

        context 'with non-empty ruby_load_path' do
          let(:params) {{:ruby_load_path => '/some/ruby/path'}}
          it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d/os-settings.conf').with({
            'ensure'  => 'file',
            'owner'   => 'root',
            'group'   => 'puppet',
            'mode'    => '0640',
            'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run
os-settings: {
    ruby-load-path: [/some/ruby/path]
}
~,
            'require' => 'Package[puppetserver]',
            'notify'  => 'Service[puppetserver]'
          }) }
        end

        context 'with empty ssl_protocols, non-empty ssl_cipher_suites, and multiple admin_api_whitelist entries' do
          let(:params) {{
            :ssl_protocols => [],
            :ssl_cipher_suites => ['suite1', 'suite2'],
            :admin_api_whitelist => ['foo.example.com', 'bar.example.com']
          }}
          it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d/puppetserver.conf').with({
            'ensure'  => 'file',
            'owner'   => 'root',
            'group'   => 'puppet',
            'mode'    => '0640',
            'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run

# configuration for the JRuby interpreters
jruby-puppet: {
    # Where the puppet-agent dependency places puppet, facter, etc...
    # Puppet server expects to load Puppet from this location
    ruby-load-path: [/opt/puppetlabs/puppet/lib/ruby/vendor_ruby]

    # This setting determines where JRuby will look for gems.  It is also
    # used by the `puppetserver gem` command line tool.
    gem-home: /opt/puppetlabs/server/data/puppetserver/jruby-gems

    # PLEASE NOTE: Use caution when modifying the below settings. Modifying
    # these settings will change the value of the corresponding Puppet settings
    # for Puppet Server, but not for the Puppet CLI tools. This likely will not
    # be a problem with master-var-dir, master-run-dir, or master-log-dir unless
    # some critical setting in puppet.conf is interpolating the value of one
    # of the corresponding settings, but it is important that any changes made to
    # master-conf-dir and master-code-dir are also made to the corresponding Puppet
    # settings when running the Puppet CLI tools. See
    # https://docs.puppetlabs.com/puppetserver/latest/puppet_conf_setting_diffs.html#overriding-puppet-settings-in-puppet-server
    # for more information.

    # (optional) path to puppet conf dir; if not specified, will use the puppet default
    master-conf-dir: /etc/puppetlabs/puppet

    # (optional) path to puppet code dir; if not specified, will use
    # /etc/puppetlabs/code
    master-code-dir: /etc/puppetlabs/code

    # (optional) path to puppet run dir; if not specified, will use
    # /var/run/puppetlabs/puppetserver
    master-run-dir: /var/run/puppetlabs/puppetserver

    # (optional) path to puppet log dir; if not specified, will use
    # /var/log/puppetlabs/puppetserver
    master-log-dir: /var/log/puppetlabs/puppetserver

    # (optional) path to puppet var dir; if not specified, will use the puppet default
    master-var-dir: /opt/puppetlabs/server/data/puppetserver

    # (optional) maximum number of JRuby instances to allow; defaults to <num-cpus>+2
    max-active-instances: 3

    # (optional) Authorize access to Puppet master endpoints via rules specified
    # in the legacy Puppet auth.conf file (if true or not specified) or via rules
    # specified in the Puppet Server HOCON-formatted auth.conf (if false).
    use-legacy-auth-conf: true
}

# settings related to HTTP client requests made by Puppet Server
http-client: {
    # A list of acceptable cipher suites for making HTTP requests
    cipher-suites: [suite1,suite2]
}

# settings related to profiling the puppet Ruby code
profiler: {
    # enable or disable profiling for the Ruby code; defaults to 'false'.
    enabled: false
}

# Settings related to the puppet-admin HTTP API
puppet-admin: {
    client-whitelist: [foo.example.com,bar.example.com]
}
~,
            'require' => 'Package[puppetserver]',
            'notify'  => 'Service[puppetserver]'
          }) }
        end

        context 'when admin_api_mountpoints does not begin with / and enable_ca => false' do
          let(:params) {{
            :admin_api_mountpoint => 'admin_mount_point',
            :enable_ca => false
          }}
          it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d/web-routes.conf').with({
            'ensure'  => 'file',
            'owner'   => 'root',
            'group'   => 'puppet',
            'mode'    => '0640',
            'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run
web-router-service: {
  "puppetlabs.services.ca.certificate-authority-service/certificate-authority-service": "/puppet-ca"

  "puppetlabs.trapperkeeper.services.status.status-service/status-service": "/status"
  "puppetlabs.services.master.master-service/master-service": "/puppet"
  "puppetlabs.services.legacy-routes.legacy-routes-service/legacy-routes-service": ""

  # This controls the mount point for the puppet admin API.
  "puppetlabs.services.puppet-admin.puppet-admin-service/puppet-admin-service": "/admin_mount_point"
}
~,
            'require' => 'Package[puppetserver]',
            'notify'  => 'Service[puppetserver]'
          }) }
        end

        context 'when enable_ca => true and ca_port == masterport' do
          let(:params) {{
            :enable_ca => false,
            :ca_port => 12345,
            :masterport => 12345

          }}
          it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d/web-routes.conf').with({
            'ensure'  => 'file',
            'owner'   => 'root',
            'group'   => 'puppet',
            'mode'    => '0640',
            'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run
web-router-service: {
  "puppetlabs.services.ca.certificate-authority-service/certificate-authority-service": "/puppet-ca"

  "puppetlabs.trapperkeeper.services.status.status-service/status-service": "/status"
  "puppetlabs.services.master.master-service/master-service": "/puppet"
  "puppetlabs.services.legacy-routes.legacy-routes-service/legacy-routes-service": ""

  # This controls the mount point for the puppet admin API.
  "puppetlabs.services.puppet-admin.puppet-admin-service/puppet-admin-service": "/puppet-admin-api"
}
~,
            'require' => 'Package[puppetserver]',
            'notify'  => 'Service[puppetserver]'
          }) }
        end

        context 'when enable_master =>false' do
          let(:params) {{ :enable_master => false }}

          it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d/webserver.conf').with({
            'ensure'  => 'file',
            'owner'   => 'root',
            'group'   => 'puppet',
            'mode'    => '0640',
            'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run
webserver: {
  ca: {
    access-log-config: /etc/puppetlabs/puppetserver/request-logging.xml
    client-auth: want
    ssl-crl-path: /etc/puppetlabs/puppet/ssl/crl.pem
    ssl-ca-cert: /etc/puppetlabs/puppet/ssl/certs/ca.pem
    ssl-cert: /etc/puppetlabs/puppet/ssl/certs/foo.example.com.pem
    ssl-key: /etc/puppetlabs/puppet/ssl/private_keys/foo.example.com.pem
    ssl-host: 0.0.0.0
    ssl-port: 8141
    default-server: true
  }
}
~,
            'require' => 'Package[puppetserver]',
            'notify'  => 'Service[puppetserver]'
          }) }
          it { is_expected.to_not contain_iptables__listen__tcp_stateful('allow_puppet') }
        end

        context 'when enable_ca =>false' do
          let(:params) {{ :enable_ca => false }}
          it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d/webserver.conf').with({
            'ensure'  => 'file',
            'owner'   => 'root',
            'group'   => 'puppet',
            'mode'    => '0640',
            'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run
webserver: {
  base: {
    access-log-config: /etc/puppetlabs/puppetserver/request-logging.xml
    client-auth: need
    ssl-crl-path: /etc/puppetlabs/puppet/ssl/crl.pem
    ssl-ca-cert: /etc/puppetlabs/puppet/ssl/certs/ca.pem
    ssl-cert: /etc/puppetlabs/puppet/ssl/certs/foo.example.com.pem
    ssl-key: /etc/puppetlabs/puppet/ssl/private_keys/foo.example.com.pem
    ssl-host: 0.0.0.0
    ssl-port: 8140
    default-server: true
  }
}
~,
            'require' => 'Package[puppetserver]',
            'notify'  => 'Service[puppetserver]'
          }) }
          it { is_expected.to_not contain_iptables__listen__tcp_stateful('allow_puppetca') }
        end

        context 'when ca_port == masterport' do
          let(:params) {{ :ca_port => 12345, :masterport => 12345 }}
          it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d/webserver.conf').with({
            'ensure'  => 'file',
            'owner'   => 'root',
            'group'   => 'puppet',
            'mode'    => '0640',
            'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run
webserver: {
  base: {
    access-log-config: /etc/puppetlabs/puppetserver/request-logging.xml
    client-auth: want
    ssl-crl-path: /etc/puppetlabs/puppet/ssl/crl.pem
    ssl-ca-cert: /etc/puppetlabs/puppet/ssl/certs/ca.pem
    ssl-cert: /etc/puppetlabs/puppet/ssl/certs/foo.example.com.pem
    ssl-key: /etc/puppetlabs/puppet/ssl/private_keys/foo.example.com.pem
    ssl-host: 0.0.0.0
    ssl-port: 12345
    default-server: true
  }
}
~,
            'require' => 'Package[puppetserver]',
            'notify'  => 'Service[puppetserver]'
          }) }
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
      end
    end
  end
end

