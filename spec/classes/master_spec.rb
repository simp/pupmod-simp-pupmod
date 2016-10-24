require 'spec_helper'

describe 'pupmod::master' do
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
      let(:pre_condition) { 'include "pupmod"' }

      describe "with default parameters" do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('apache') }
        it { is_expected.to create_class('pupmod') }
        it { is_expected.to create_class('pupmod::master::sysconfig') }
        it { is_expected.to create_class('pupmod::master::reports') }
        it { is_expected.to create_class('pupmod::master::base') }
        it { is_expected.to contain_class('pupmod::master::sysconfig').that_comes_before('Service[puppetserver]') }
        it { is_expected.to contain_file('/etc/puppetserver').with({
          'ensure' => 'directory',
          'owner'  => 'root',
          'group'  => 'puppet',
          'mode'   => '0640'
        }) }

        it { is_expected.to contain_file('/etc/puppetserver/conf.d').with({
          'ensure' => 'directory',
          'owner'  => 'root',
          'group'  => 'puppet',
          'mode'   => '0640'
        }) }

        it { is_expected.to contain_file('/etc/puppetserver/bootstrap.cfg').with({
          'ensure'  => 'file',
          'owner'   => 'root',
          'group'   => 'puppet',
          'mode'    => '0640',
          'content' => %q{# This file managed by Puppet
# Any changes will be removed on the next run
puppetlabs.services.request-handler.request-handler-service/request-handler-service
puppetlabs.services.jruby.jruby-puppet-service/jruby-puppet-pooled-service
puppetlabs.services.puppet-profiler.puppet-profiler-service/puppet-profiler-service
puppetlabs.trapperkeeper.services.webserver.jetty9-service/jetty9-service
puppetlabs.trapperkeeper.services.webrouting.webrouting-service/webrouting-service
puppetlabs.services.config.puppet-server-config-service/puppet-server-config-service
puppetlabs.services.master.master-service/master-service
puppetlabs.services.version.version-check-service/version-check-service
puppetlabs.services.puppet-admin.puppet-admin-service/puppet-admin-service

puppetlabs.services.ca.certificate-authority-service/certificate-authority-service
},
          'require' => 'Package[puppetserver]',
          'notify'  => 'Service[puppetserver]'
        }) }

        it { is_expected.to contain_file('/etc/puppetserver/logback.xml').with({
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
        <file>/var/log/puppetserver/puppetserver.log</file>
        <append>true</append>
        <encoder>
            <pattern>%d %-5p [%c{2}] %m%n</pattern>
        </encoder>
    </appender>

    <logger name="org.eclipse.jetty" level="WARN"/>

    <root level="WARN">
        <appender-ref ref="SYSLOG"/>
    </root>
</configuration>
~,
          'require' => 'Package[puppetserver]',
          'notify'  => 'Service[puppetserver]'
        }) }

        it { is_expected.to contain_file('/etc/puppetserver/conf.d/ca.conf').with({
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
    }
}
~,
          'require' => 'Package[puppetserver]',
          'notify'  => 'Service[puppetserver]'
        }) }

        it { is_expected.to_not contain_file('/etc/puppetserver/conf.d/os-settings.conf') }
        it { is_expected.to contain_file('/etc/puppetserver/conf.d/puppetserver.conf').with({
          'ensure'  => 'file',
          'owner'   => 'root',
          'group'   => 'puppet',
          'mode'    => '0640',
          'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run

# configuration for the JRuby interpreters
jruby-puppet: {
    # This setting determines where JRuby will look for gems.  It is also
    # used by the `puppetserver gem` command line tool.
    gem-home: /var/lib/puppet/jruby-gems

    # (optional) path to puppet conf dir; if not specified, will use the puppet default
    master-conf-dir: /etc/puppet

    # (optional) path to puppet var dir; if not specified, will use the puppet default
    master-var-dir: /var/lib/puppet

    # (optional) maximum number of JRuby instances to allow; defaults to <num-cpus>+2
    max-active-instances: 3
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

        it { is_expected.to contain_file('/etc/puppetserver/conf.d/web-routes.conf').with({
          'ensure'  => 'file',
          'owner'   => 'root',
          'group'   => 'puppet',
          'mode'    => '0640',
          'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run
web-router-service: {
    # These two should not be modified because the Puppet 3.x agent expects them to
    # be mounted at "/"
    "puppetlabs.services.ca.certificate-authority-service/certificate-authority-service": {
      default: {
        route: ""
        server: "ca"
      }
    }
    "puppetlabs.services.master.master-service/master-service": ""

    # This controls the mount point for the puppet admin API.
    "puppetlabs.services.puppet-admin.puppet-admin-service/puppet-admin-service": "/puppet-admin-api"
}
~,
          'require' => 'Package[puppetserver]',
          'notify'  => 'Service[puppetserver]'
        }) }

        it { is_expected.to contain_file('/etc/puppetserver/conf.d/webserver.conf').with({
          'ensure'  => 'file',
          'owner'   => 'root',
          'group'   => 'puppet',
          'mode'    => '0640',
          'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run
webserver: {
  base: {
    client-auth: need
    ssl-crl-path: /var/lib/puppet/ssl/crl.pem
    ssl-ca-cert: /var/lib/puppet/ssl/certs/ca.pem
    ssl-cert: /var/lib/puppet/ssl/certs/foo.example.com.pem
    ssl-key: /var/lib/puppet/ssl/private_keys/foo.example.com.pem
    ssl-host: 0.0.0.0
    ssl-port: 8140
    default-server: true
  }
  ca: {
    client-auth: want
    ssl-crl-path: /var/lib/puppet/ssl/crl.pem
    ssl-ca-cert: /var/lib/puppet/ssl/certs/ca.pem
    ssl-cert: /var/lib/puppet/ssl/certs/foo.example.com.pem
    ssl-key: /var/lib/puppet/ssl/private_keys/foo.example.com.pem
    ssl-host: 0.0.0.0
    ssl-port: 8141
  }
}
~,
          'require' => 'Package[puppetserver]',
          'notify'  => 'Service[puppetserver]'
        }) }

        it { is_expected.to contain_pupmod__conf('master_environmentpath').with({
          'section' => ['master'],
          'setting' => 'environmentpath',
          'value'   => '/etc/puppet/environments',
          'notify'  => 'Service[puppetserver]'
        }) }

        it { is_expected.to contain_pupmod__conf('master_daemonize').with({
          'section' => ['master'],
          'setting' => 'daemonize',
          'value'   => 'true',
          'notify'  => 'Service[puppetserver]'
        }) }

        it { is_expected.to contain_pupmod__conf('master_masterport').with({
          'section' => ['master'],
          'setting' => 'masterport',
          'value'   => '8140',
          'notify'  => 'Service[puppetserver]'
        }) }

        it { is_expected.to contain_pupmod__conf('master_ca').with({
          'section' => ['master'],
          'setting' => 'ca',
          'value'   => 'true',
          'notify'  => 'Service[puppetserver]'
        }) }

        it { is_expected.to contain_pupmod__conf('master_ca_port').with({
          'section' => ['master'],
          'setting' => 'ca_port',
          'value'   => '8141',
          'notify'  => 'Service[puppetserver]'
        }) }

        it { is_expected.to contain_pupmod__conf('ca_ttl').with({
          'section' => ['master'],
          'setting' => 'ca_ttl',
          'value'   => '10y',
          'notify'  => 'Service[puppetserver]'
        }) }

        # fips_enabled fact take precedence over hieradata use_fips
        it { is_expected.to contain_pupmod__conf('keylength').with({
          'section' => ['master'],
          'setting' => 'keylength',
          'value'   => '4096',
          'notify'  => 'Service[puppetserver]'
        }) }

        it { is_expected.to contain_pupmod__conf('freeze_main').with({
          'setting' => 'freeze_main',
          'value'   => 'false',
          'notify'  => 'Service[puppetserver]'
        }) }

        it { is_expected.to contain_class('iptables') }
        it {
          pending "Requires fix to simplib's nets2cidr, which does not convert IPv4 addresses to CIDR"
          is_expected.to contain_iptables__add_tcp_stateful_listen('allow_puppet').with({
            'order'       => '11',
            'client_nets' => ['127.0.0.1/32','::1/128'],
            'dports'      => '8140'
        }) }

        it {
          pending "Requires fix to simplib's nets2cidr, which does not convert IPv4 addresses to CIDR"
          is_expected.to contain_iptables__add_tcp_stateful_listen('allow_puppetca').with({
            'order'       => '11',
            'client_nets' => ['127.0.0.1/32','::1/128'],
            'dports'      => '8141'
        }) }
      end

      describe "with non-default parameters" do
        context 'with enable_ca => false' do
          let(:params) {{:enable_ca => false}}
          it { is_expected.to contain_file('/etc/puppetserver/bootstrap.cfg').with({
            'ensure'  => 'file',
            'owner'   => 'root',
            'group'   => 'puppet',
            'mode'    => '0640',
            'content' => %q{# This file managed by Puppet
# Any changes will be removed on the next run
puppetlabs.services.request-handler.request-handler-service/request-handler-service
puppetlabs.services.jruby.jruby-puppet-service/jruby-puppet-pooled-service
puppetlabs.services.puppet-profiler.puppet-profiler-service/puppet-profiler-service
puppetlabs.trapperkeeper.services.webserver.jetty9-service/jetty9-service
puppetlabs.trapperkeeper.services.webrouting.webrouting-service/webrouting-service
puppetlabs.services.config.puppet-server-config-service/puppet-server-config-service
puppetlabs.services.master.master-service/master-service
puppetlabs.services.version.version-check-service/version-check-service
puppetlabs.services.puppet-admin.puppet-admin-service/puppet-admin-service

puppetlabs.services.ca.certificate-authority-disabled-service/certificate-authority-disabled-service
},
            'require' => 'Package[puppetserver]',
            'notify'  => 'Service[puppetserver]'
          }) }
        end

        context 'with log_to_syslog => false and log_to_file => true' do
          let(:params) {{:log_to_syslog => false, :log_to_file => true}}
          it { is_expected.to contain_file('/etc/puppetserver/logback.xml').with({
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
        <file>/var/log/puppetserver/puppetserver.log</file>
        <append>true</append>
        <encoder>
            <pattern>%d %-5p [%c{2}] %m%n</pattern>
        </encoder>
    </appender>

    <logger name="org.eclipse.jetty" level="WARN"/>

    <root level="WARN">
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
          it { is_expected.to contain_file('/etc/puppetserver/conf.d/ca.conf').with({
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
    }
}
~,
            'require' => 'Package[puppetserver]',
            'notify'  => 'Service[puppetserver]'
          }) }
        end

        context 'with non-empty ruby_load_path' do
          let(:params) {{:ruby_load_path => '/some/ruby/path'}}
          it { is_expected.to contain_file('/etc/puppetserver/conf.d/os-settings.conf').with({
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

        context 'with non-empty gem_home, empty ssl_protocols, non-empty ssl_cipher_suites, and multiple admin_api_whitelist entries' do
          let(:params) {{
            :gem_home => '/some/gem/path',
            :ssl_protocols => [],
            :ssl_cipher_suites => ['suite1', 'suite2'],
            :admin_api_whitelist => ['foo.example.com', 'bar.example.com']
          }}
          it { is_expected.to contain_file('/etc/puppetserver/conf.d/puppetserver.conf').with({
            'ensure'  => 'file',
            'owner'   => 'root',
            'group'   => 'puppet',
            'mode'    => '0640',
            'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run

# configuration for the JRuby interpreters
jruby-puppet: {
    # This setting determines where JRuby will look for gems.  It is also
    # used by the `puppetserver gem` command line tool.
    gem-home: /some/gem/path

    # (optional) path to puppet conf dir; if not specified, will use the puppet default
    master-conf-dir: /etc/puppet

    # (optional) path to puppet var dir; if not specified, will use the puppet default
    master-var-dir: /var/lib/puppet

    # (optional) maximum number of JRuby instances to allow; defaults to <num-cpus>+2
    max-active-instances: 3
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
          it { is_expected.to contain_file('/etc/puppetserver/conf.d/web-routes.conf').with({
            'ensure'  => 'file',
            'owner'   => 'root',
            'group'   => 'puppet',
            'mode'    => '0640',
            'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run
web-router-service: {
    # These two should not be modified because the Puppet 3.x agent expects them to
    # be mounted at "/"
    "puppetlabs.services.ca.certificate-authority-service/certificate-authority-service": ""
    "puppetlabs.services.master.master-service/master-service": ""

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
            :ca_port => '12345',
            :masterport => '12345'

          }}
          it { is_expected.to contain_file('/etc/puppetserver/conf.d/web-routes.conf').with({
            'ensure'  => 'file',
            'owner'   => 'root',
            'group'   => 'puppet',
            'mode'    => '0640',
            'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run
web-router-service: {
    # These two should not be modified because the Puppet 3.x agent expects them to
    # be mounted at "/"
    "puppetlabs.services.ca.certificate-authority-service/certificate-authority-service": ""
    "puppetlabs.services.master.master-service/master-service": ""

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

          it { is_expected.to contain_file('/etc/puppetserver/conf.d/webserver.conf').with({
            'ensure'  => 'file',
            'owner'   => 'root',
            'group'   => 'puppet',
            'mode'    => '0640',
            'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run
webserver: {
  ca: {
    client-auth: want
    ssl-crl-path: /var/lib/puppet/ssl/crl.pem
    ssl-ca-cert: /var/lib/puppet/ssl/certs/ca.pem
    ssl-cert: /var/lib/puppet/ssl/certs/foo.example.com.pem
    ssl-key: /var/lib/puppet/ssl/private_keys/foo.example.com.pem
    ssl-host: 0.0.0.0
    ssl-port: 8141
    default-server: true
  }
}
~,
            'require' => 'Package[puppetserver]',
            'notify'  => 'Service[puppetserver]'
          }) }
        end

        context 'when enable_ca =>false' do
          let(:params) {{ :enable_ca => false }}
          it { is_expected.to contain_file('/etc/puppetserver/conf.d/webserver.conf').with({
            'ensure'  => 'file',
            'owner'   => 'root',
            'group'   => 'puppet',
            'mode'    => '0640',
            'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run
webserver: {
  base: {
    client-auth: need
    ssl-crl-path: /var/lib/puppet/ssl/crl.pem
    ssl-ca-cert: /var/lib/puppet/ssl/certs/ca.pem
    ssl-cert: /var/lib/puppet/ssl/certs/foo.example.com.pem
    ssl-key: /var/lib/puppet/ssl/private_keys/foo.example.com.pem
    ssl-host: 0.0.0.0
    ssl-port: 8140
    default-server: true
  }
}
~,
            'require' => 'Package[puppetserver]',
            'notify'  => 'Service[puppetserver]'
          }) }
        end

        context 'when ca_port == masterport' do
          let(:params) {{ :ca_port => 12345, :masterport => 12345 }}
          it { is_expected.to contain_file('/etc/puppetserver/conf.d/webserver.conf').with({
            'ensure'  => 'file',
            'owner'   => 'root',
            'group'   => 'puppet',
            'mode'    => '0640',
            'content' => %q~# This file managed by Puppet
# Any changes will be removed on the next run
webserver: {
  base: {
    client-auth: want
    ssl-crl-path: /var/lib/puppet/ssl/crl.pem
    ssl-ca-cert: /var/lib/puppet/ssl/certs/ca.pem
    ssl-cert: /var/lib/puppet/ssl/certs/foo.example.com.pem
    ssl-key: /var/lib/puppet/ssl/private_keys/foo.example.com.pem
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
      end
    end
  end
end
