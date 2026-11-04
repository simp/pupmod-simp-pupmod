# @summary Edit the puppetserver configuration files in place
#
# Each setting is written only when the `pupmod::master` parameter that
# controls it is set, so settings that are not managed keep whatever the
# package or an administrator wrote.
#
# @api private
#
class pupmod::master::config {
  assert_private()

  $_confdir = $pupmod::master::confdir
  $_conf_base = dirname($_confdir)
  # The fact reads the default conf.d, so it only describes that one
  $_webserver = $_confdir ? {
    '/etc/puppetlabs/puppetserver/conf.d' => $facts['puppetserver_webserver'],
    default                               => undef,
  }

  $_resource_defaults = {
    'require' => Class['pupmod::master::install'],
    'notify'  => Class['pupmod::master::service'],
  }

  ##########
  # ca.cfg #
  ##########

  if $pupmod::master::enable_ca =~ NotUndef {
    $_ca_service = $pupmod::master::enable_ca ? {
      true    => 'puppetlabs.services.ca.certificate-authority-service/certificate-authority-service',
      default => 'puppetlabs.services.ca.certificate-authority-disabled-service/certificate-authority-disabled-service',
    }

    file_line { 'pupmod::master ca.cfg certificate-authority-service':
      path  => "${_conf_base}/services.d/ca.cfg",
      line  => $_ca_service,
      match => '^\s*puppetlabs\.services\.ca\.certificate-authority-(disabled-)?service/',
      *     => $_resource_defaults,
    }
  }

  ##################
  # webserver.conf #
  ##################

  # The port the main server listens on: the parameter, else what
  # webserver.conf says now, else the puppetserver default
  $_masterport = $pupmod::master::masterport ? {
    Integer => $pupmod::master::masterport,
    default => pick($_webserver.dig('ssl-port'), $_webserver.dig('base', 'ssl-port'), 8140),
  }

  # Whether the CA runs as its own server on its own port. undef means it
  # isn't known, and the CA's server and route are left alone.
  if ($pupmod::master::enable_ca == false) or ($pupmod::master::ca_port == 'absent') {
    $_ca_split = false
  }
  elsif $pupmod::master::ca_port =~ Integer {
    $_ca_split = $pupmod::master::ca_port != $_masterport
  }
  else {
    $_ca_split = undef
  }

  # A webserver.conf with named servers holds one Hash per server
  $_named_servers_now = $_webserver ? {
    Hash    => $_webserver.any |$key, $value| { $value =~ Hash },
    default => false,
  }

  $_extra_webserver_sections = pick($pupmod::master::extra_webserver_sections, {})

  # A CA on its own port, or another server, needs named servers
  $_named_servers = $_named_servers_now or ($_ca_split == true) or !empty($_extra_webserver_sections)

  if $_named_servers and !$_named_servers_now {
    # Move the single server's settings into the 'base' server. Without a
    # webserver.conf yet (the package is installed in this run), these are
    # the settings the package ships.
    $_single_server = $_webserver ? {
      Hash    => $_webserver,
      default => {
        'access-log-config' => '/etc/puppetlabs/puppetserver/request-logging.xml',
        'client-auth'       => 'want',
        'ssl-host'          => '0.0.0.0',
        'ssl-port'          => 8140,
      },
    }

    $_moved = $_single_server
    $_unnested = $_single_server.keys.reduce({}) |$memo, $key| { $memo + { $key => 'absent' } }
  }
  else {
    $_moved = {}
    $_unnested = {}
  }

  $_ssl_protocols = $pupmod::master::ssl_protocols ? {
    Array   => join($pupmod::master::ssl_protocols, ','),
    default => $pupmod::master::ssl_protocols,
  }

  $_cipher_suites = $pupmod::master::ssl_cipher_suites ? {
    Array   => join($pupmod::master::ssl_cipher_suites, ','),
    default => $pupmod::master::ssl_cipher_suites,
  }

  # With the CA on the main port, the main server must accept agents
  # without certificates so they can submit certificate requests. Without a
  # CA, it requires them.
  if $pupmod::master::enable_ca == false {
    $_client_auth = 'need'
  }
  else {
    $_client_auth = $_ca_split ? {
      true    => 'need',
      false   => 'want',
      default => undef,
    }
  }

  # 'absent' removes masterport from puppet.conf only; the server must keep
  # a port to listen on
  $_ssl_port = $pupmod::master::masterport ? {
    Integer => $pupmod::master::masterport,
    default => undef,
  }

  # Unset parameters must not replace the settings moved into 'base'
  $_main_server_params = ({
    'ssl-host'      => $pupmod::master::bind_address,
    'ssl-port'      => $_ssl_port,
    'ssl-protocols' => $_ssl_protocols,
    'cipher-suites' => $_cipher_suites,
    'client-auth'   => $_client_auth,
  } + pick($pupmod::master::server_webserver_options, {})).filter |$key, $value| { $value =~ NotUndef }

  $_main_server_settings = $_moved + $_main_server_params

  if $_named_servers {
    if $pupmod::master::enable_master == false {
      $_main_server = { 'webserver.base' => 'absent' }
    }
    else {
      # The main server takes every route that doesn't name a server
      $_main_server = ($_main_server_settings + { 'default-server' => true }).reduce({}) |$memo, $setting| {
        $memo + { "webserver.base.${setting[0]}" => $setting[1] }
      }
    }
  }
  else {
    $_main_server = $_main_server_settings.reduce({}) |$memo, $setting| {
      $memo + { "webserver.${setting[0]}" => $setting[1] }
    }
  }

  if $_ca_split == true {
    $_ssldir = $pupmod::ssldir
    $_fqdn = $facts['networking']['fqdn']

    $_bind_address = $pupmod::master::bind_address ? {
      'absent' => undef,
      default  => $pupmod::master::bind_address,
    }

    # Without a main server, the CA takes every route that doesn't name a
    # server; with one, the main server does
    $_ca_default_server = $pupmod::master::enable_master ? {
      false   => true,
      true    => 'absent',
      default => undef,
    }

    # Everything the CA needs to run as its own server
    $_ca_server_settings = {
      'access-log-config' => '/etc/puppetlabs/puppetserver/request-logging.xml',
      'client-auth'       => 'want',
      'ssl-crl-path'      => "${_ssldir}/crl.pem",
      'ssl-ca-cert'       => "${_ssldir}/certs/ca.pem",
      'ssl-cert'          => "${pupmod::master::ssldir}/certs/${_fqdn}.pem",
      'ssl-key'           => "${pupmod::master::ssldir}/private_keys/${_fqdn}.pem",
      'ssl-host'          => pick(
        $pupmod::master::ca_bind_address,
        $_bind_address,
        $_webserver.dig('ssl-host'),
        $_webserver.dig('base', 'ssl-host'),
        '0.0.0.0'
      ),
      'ssl-port'          => $pupmod::master::ca_port,
      'ssl-protocols'     => $_ssl_protocols,
      'cipher-suites'     => $_cipher_suites,
      'default-server'    => $_ca_default_server,
    } + pick($pupmod::master::ca_webserver_options, {})

    $_ca_server = $_ca_server_settings.reduce({}) |$memo, $setting| {
      $memo + { "webserver.ca.${setting[0]}" => $setting[1] }
    }
  }
  elsif $_ca_split == false {
    $_ca_server = { 'webserver.ca' => 'absent' }
  }
  else {
    $_ca_server = {}
  }

  $_extra_servers = $_extra_webserver_sections.reduce({}) |$memo, $section| {
    $memo + $section[1].reduce({}) |$section_memo, $setting| {
      $section_memo + { "webserver.${section[0]}.${setting[0]}" => $setting[1] }
    }
  }

  $_webserver_settings = $_unnested.reduce({}) |$memo, $setting| {
    $memo + { "webserver.${setting[0]}" => $setting[1] }
  } + $_main_server + $_ca_server + $_extra_servers

  ###################
  # web-routes.conf #
  ###################

  $_ca_route = $_ca_split ? {
    true    => { 'default' => { 'route' => '/puppet-ca', 'server' => 'ca' } },
    false   => '/puppet-ca',
    default => undef,
  }

  # puppetserver needs a route for every service it runs
  if $pupmod::master::admin_api_mountpoint == 'absent' {
    fail('pupmod::master::admin_api_mountpoint cannot be removed: puppetserver needs a route for its admin API. Leave it unset to keep the current route.')
  }

  $_admin_route = $pupmod::master::admin_api_mountpoint ? {
    undef   => undef,
    /^\//   => $pupmod::master::admin_api_mountpoint,
    default => "/${pupmod::master::admin_api_mountpoint}",
  }

  ############################################
  # puppetserver.conf, ca.conf, product.conf #
  ############################################

  $_max_active_instances = $pupmod::master::max_active_instances ? {
    'auto'  => pupmod::max_active_instances($pupmod::master::server_type),
    default => $pupmod::master::max_active_instances,
  }

  $_ca_status_whitelist = $pupmod::master::ca_status_whitelist ? {
    undef    => {},
    'absent' => { 'certificate-authority.certificate-status' => 'absent' },
    default  => {
      'certificate-authority.certificate-status.client-whitelist'       => $pupmod::master::ca_status_whitelist,
      'certificate-authority.certificate-status.authorization-required' => true,
    },
  }

  # server-*-dir replaced the deprecated master-*-dir settings, so setting
  # one removes the other
  $_server_dirs = {
    'conf' => $pupmod::master::server_conf_dir,
    'code' => $pupmod::master::server_code_dir,
    'var'  => $pupmod::master::server_var_dir,
    'run'  => $pupmod::master::server_run_dir,
    'log'  => $pupmod::master::server_log_dir,
  }.filter |$dir, $value| { $value =~ NotUndef }.reduce({}) |$memo, $dir| {
    $memo + {
      "jruby-puppet.server-${dir[0]}-dir" => $dir[1],
      "jruby-puppet.master-${dir[0]}-dir" => 'absent',
    }
  }

  $_hocon_settings = {
    "${_confdir}/puppetserver.conf" => $_server_dirs + {
      'jruby-puppet.max-active-instances'            => $_max_active_instances,
      'jruby-puppet.max-requests-per-instance'       => $pupmod::master::max_requests_per_instance,
      'jruby-puppet.borrow-timeout'                  => $pupmod::master::borrow_timeout,
      'jruby-puppet.environment-class-cache-enabled' => $pupmod::master::environment_class_cache_enabled,
      'jruby-puppet.compile-mode'                    => $pupmod::master::compile_mode,
      'jruby-puppet.use-legacy-auth-conf'            => $pupmod::master::use_legacy_auth_conf,
      'jruby-puppet.max-queued-requests'             => $pupmod::master::max_queued_requests,
      'jruby-puppet.max-retry-delay'                 => $pupmod::master::max_retry_delay,
      'jruby-puppet.profiling-mode'                  => $pupmod::master::profiling_mode,
      'jruby-puppet.profiler-output-file'            => $pupmod::master::profiler_output_file,
      'http-client.ssl-protocols'                    => $pupmod::master::ssl_protocols,
      'http-client.cipher-suites'                    => $pupmod::master::ssl_cipher_suites,
      'profiler.enabled'                             => $pupmod::master::enable_profiler,
      'puppet-admin.client-whitelist'                => $pupmod::master::admin_api_whitelist,
    },
    "${_confdir}/ca.conf"           => $_ca_status_whitelist + {
      'certificate-authority.allow-authorization-extensions' => $pupmod::master::ca_allow_auth_extensions,
      'certificate-authority.allow-subject-alt-names'        => $pupmod::master::ca_allow_alt_names,
    },
    "${_confdir}/webserver.conf"    => $_webserver_settings,
    "${_confdir}/web-routes.conf"   => {
      'web-router-service."puppetlabs.services.ca.certificate-authority-service/certificate-authority-service"' => $_ca_route,
      'web-router-service."puppetlabs.services.puppet-admin.puppet-admin-service/puppet-admin-service"'         => $_admin_route,
    },
    "${_confdir}/product.conf"      => {
      'product.check-for-updates' => $pupmod::master::enable_analytics,
    },
  }

  $_hocon_settings.each |Stdlib::Absolutepath $path, Hash $settings| {
    $settings.each |String[1] $setting, $value| {
      if $value =~ NotUndef {
        $_ensure = $value ? {
          'absent' => 'absent',
          default  => 'present',
        }

        # hocon_setting writes a one-element Array as a scalar unless told
        $_type = $value ? {
          Array   => 'array',
          default => undef,
        }

        hocon_setting { "pupmod::master ${basename($path)} ${setting}":
          ensure  => $_ensure,
          path    => $path,
          setting => $setting,
          value   => $value,
          type    => $_type,
          *       => $_resource_defaults,
        }
      }
    }
  }

  ####################
  # os-settings.conf #
  ####################

  if $pupmod::master::ruby_load_path =~ NotUndef {
    $_ruby_load_path_ensure = $pupmod::master::ruby_load_path ? {
      'absent' => 'absent',
      default  => 'present',
    }

    hocon_setting { 'pupmod::master os-settings.conf os-settings.ruby-load-path':
      ensure  => $_ruby_load_path_ensure,
      path    => "${_confdir}/os-settings.conf",
      setting => 'os-settings.ruby-load-path',
      value   => [$pupmod::master::ruby_load_path],
      type    => 'array',
      *       => $_resource_defaults,
    }
  }

  ###############
  # logback.xml #
  ###############

  $_logback = "${_conf_base}/logback.xml"
  $_logback_defaults = {
    'notify'  => Class['pupmod::master::service'],
    'incl'    => $_logback,
    'lens'    => 'Xml.lns',
    'context' => "/files${_logback}/configuration",
  }

  if $pupmod::master::log_level =~ NotUndef {
    augeas { 'pupmod::master logback.xml log_level':
      changes => [
        "set logger[#attribute/name='org.eclipse.jetty']/#attribute/level ${pupmod::master::log_level}",
        "set root/#attribute/level ${pupmod::master::log_level}",
      ],
      require => Class['pupmod::master::install'],
      *       => $_logback_defaults,
    }
  }

  if $pupmod::master::syslog == true {
    # Appenders must be defined before the loggers that refer to them
    augeas { 'pupmod::master logback.xml SYSLOG appender':
      changes => [
        "ins appender before *[label() = 'logger' or label() = 'root'][1]",
        'set appender[count(*) = 0]/#attribute/name SYSLOG',
      ],
      # Matches only when logback.xml exists and has no SYSLOG appender, so
      # the insert always has a logger to go before (logback.xml is missing
      # on a fresh node under --noop)
      onlyif  => "match root[count(../appender[#attribute/name='SYSLOG']) = 0] size == 1",
      require => Class['pupmod::master::install'],
      *       => $_logback_defaults,
    }

    augeas { 'pupmod::master logback.xml SYSLOG':
      changes => [
        "set appender[#attribute/name='SYSLOG']/#attribute/class ch.qos.logback.classic.net.SyslogAppender",
        "set appender[#attribute/name='SYSLOG']/syslogHost/#text localhost",
        "set appender[#attribute/name='SYSLOG']/facility/#text ${pupmod::master::syslog_facility}",
        "set appender[#attribute/name='SYSLOG']/suffixPattern/#text '${pupmod::master::syslog_message_format}'",
        "set appender[#attribute/name='SYSLOG']/throwableExcluded/#text true",
        "set root/appender-ref[#attribute/ref='SYSLOG']/#attribute/ref SYSLOG",
      ],
      require => [Class['pupmod::master::install'], Augeas['pupmod::master logback.xml SYSLOG appender']],
      *       => $_logback_defaults,
    }
  }
  elsif $pupmod::master::syslog == false {
    augeas { 'pupmod::master logback.xml SYSLOG':
      changes => ["rm root/appender-ref[#attribute/ref='SYSLOG']"],
      require => Class['pupmod::master::install'],
      *       => $_logback_defaults,
    }
  }

  if $pupmod::master::log_to_file =~ NotUndef {
    $_log_to_file = $pupmod::master::log_to_file ? {
      true    => "set root/appender-ref[#attribute/ref='F1']/#attribute/ref F1",
      default => "rm root/appender-ref[#attribute/ref='F1']",
    }

    augeas { 'pupmod::master logback.xml F1':
      changes => [$_log_to_file],
      require => Class['pupmod::master::install'],
      *       => $_logback_defaults,
    }
  }
}
