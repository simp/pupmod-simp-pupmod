require 'spec_helper_acceptance'

describe 'install environment via r10k and openvox-server' do
  require_relative('lib/util')

  include GenerateTypesTestUtil
  include PupmodTestUtil

  let(:master_manifest) do
    <<~EOF
      # Set up a puppetserver
      class { 'pupmod::master':
        firewall     => true,
        trusted_nets => ['ALL']
      }

      pupmod::master::autosign { 'All Test Hosts': entry => '*' }

      # Maintain connection to the VMinstall env
      pam::access::rule { 'vagrant_all':
        users      => ['vagrant'],
        permission => '+',
        origins    => ['ALL'],
      }
      sudo::user_specification { 'vagrant':
        user_list => ['vagrant'],
        cmnd      => ['ALL'],
        passwd    => false,
      }

      sshd_config { 'PermitRootLogin'    : value => 'yes' }
      sshd_config { 'AuthorizedKeysFile' : value => '.ssh/authorized_keys' }
    EOF
  end

  # Deliberately minimal. #241 is an agent-side regression in how `pupmod`
  # manages the puppetagent_manage_all_files SELinux boolean, so that class is
  # all the first-run noop check needs. simp:defaults is enforced, so the
  # boolean is managed at all.
  #
  # Using the full master manifest here fails the noop for unrelated reasons:
  # simp_firewalld's Firewalld_service provider cannot evaluate on a fresh host
  # because `firewall-offline-cmd --zone 99_simp --list-services` exits 112
  # (INVALID_ZONE) until a real, non-noop run has created that zone. That is the
  # same first-run-noop bootstrap problem as #241, but in a different module,
  # and it masks the regression this example exists to catch.
  let(:noop_manifest) do
    <<~EOF
      class { 'pupmod':
        enable_puppet_master => false,
        firewall             => false,
      }
    EOF
  end

  hosts_with_role(hosts, 'simp_master').each do |master|
    context "on #{master}" do
      it 'enables SIMP and SIMP dependencies repos' do
        os_maj = fact_on(master, 'os.release.major')
        architecture = fact_on(master, 'os.architecture')
        # Same lookup order simp-beaker-helpers uses to install the agent
        collection = ENV['BEAKER_OPENVOX_COLLECTION'] || ENV['BEAKER_PUPPET_COLLECTION'] || master.options['puppet_collection'] || 'openvox9'

        repo_content = <<~REPO
          [openvox-release]
          name=Openvox
          baseurl=https://yum.voxpupuli.org/#{collection}/el/#{os_maj}/#{architecture}/
          enabled=1
          gpgcheck=0
        REPO
        create_remote_file(master, '/etc/yum.repos.d/openvox.repo', repo_content)
      end

      it 'installs openvox and deps' do
        master.install_package('cronie')
        master.install_package('firewalld')
        if on(master, 'cat /proc/sys/crypto/fips_enabled', accept_all_exit_codes: true).stdout.strip == '1'
          # Change to the following when it works for all RHEL-like OSs
          # if master.fips_mode?
          master.install_package('yum-utils')
          master.install_package('java-headless')
          on(master, 'yumdownloader openvox-server')
          on(master, 'rpm -i --force --nodigest --nofiledigest openvox-server*.rpm')
        else
          master.install_package('openvox-server')
        end
      end

      it 'enables autosigning' do
        on(master, 'puppet config --section master set autosign true')
      end

      it 'corrects the permissions' do
        on(master, 'chown -R puppet:puppet /etc/puppetlabs/code')
      end

      context 'with a bare include' do
        let(:watched_files) do
          [
            '/etc/puppetlabs/puppet/puppet.conf',
            '/etc/sysconfig/puppetserver',
            '/etc/puppetlabs/puppetserver/conf.d/*.conf',
            '/etc/puppetlabs/puppetserver/services.d/ca.cfg',
            '/etc/puppetlabs/puppetserver/logback.xml',
          ].join(' ')
        end
        let(:bare_manifest) { "class { 'pupmod': enable_puppet_master => true }" }
        let(:state_cmd) do
          "md5sum #{watched_files}; stat -c '%U:%G %a %n' /etc/puppetlabs/puppet /etc/puppetlabs/puppetserver/conf.d; " \
            'systemctl is-enabled puppet puppetserver; systemctl is-active puppet puppetserver; ' \
            'ls /etc/systemd/system /etc/tmpfiles.d /usr/local/sbin /usr/local/bin'
        end

        it 'changes nothing but the packages' do
          before_state = on(master, state_cmd, accept_all_exit_codes: true).stdout
          apply_manifest_on(master, bare_manifest, catch_failures: true)
          expect(on(master, state_cmd, accept_all_exit_codes: true).stdout).to eq(before_state)
        end

        it 'is idempotent' do
          apply_manifest_on(master, bare_manifest, catch_changes: true)
        end
      end

      it 'does not fail a first-run noop before the puppet sebool package exists' do
        os_maj = fact_on(master, 'os.release.major').to_i

        skip('Only relevant on EL10+') if os_maj < 10

        original_mode = on(master, 'getenforce').stdout.strip
        skip('SELinux is disabled') if original_mode == 'Disabled'

        sebool_package = 'selinux-policy-targeted-extra'
        package_was_installed = on(master, "rpm -q #{sebool_package}", acceptable_exit_codes: [0, 1]).exit_code == 0
        installed_names = "rpm -qa --qf '%{NAME}\\n'"
        removed = []

        begin
          # Reproduce the #241 first-run state deterministically rather than
          # skipping when the package happens to be present: on a re-provisioned
          # or preinstalled SUT the regression would otherwise never be exercised.
          #
          # Let dnf resolve the removal instead of `rpm -e`. EL10 images ship
          # selinux-policy-extra, which carries
          # `Requires: (selinux-policy-targeted-extra if selinux-policy-targeted)`,
          # so a bare `rpm -e` is refused. Naming both packages would fix today's
          # image and break on the next one that adds a reverse dependency, so
          # diff the installed set instead and let `ensure` restore exactly what
          # went away. `--noautoremove` keeps the transaction from also sweeping
          # out orphans, whose set varies by image.
          if package_was_installed
            before = on(master, installed_names).stdout.split("\n")
            on(master, "dnf -y remove --noautoremove #{sebool_package}")
            removed = before - on(master, installed_names).stdout.split("\n")
          end

          on(master, 'setenforce 1')
          expect(on(master, 'getenforce').stdout.strip).to eq('Enforcing')

          # Guard the precondition: if the boolean is somehow still defined the
          # noop below proves nothing, so fail loudly instead of passing vacuously.
          boolean_check = on(master, 'getsebool puppetagent_manage_all_files', accept_all_exit_codes: true)
          expect(boolean_check.exit_code).not_to eq(0),
                                                 'puppetagent_manage_all_files still exists after removing ' \
                                                 "#{sebool_package}; the #241 first-run scenario was not reproduced"

          set_simp_defaults_hieradata_on(master)
          result = apply_manifest_on(master, noop_manifest, catch_failures: true, noop: true)
          expect(result.output).to match(%r{Exec\[Set puppetagent_manage_all_files seboolean\].*\(noop\)})
        ensure
          # Leave the SUT as we found it: the following examples assume the
          # original enforcement mode, and a leaked `Enforcing` would change the
          # conditions of the first real apply.
          on(master, "setenforce #{(original_mode == 'Enforcing') ? '1' : '0'}", accept_all_exit_codes: true)
          on(master, "dnf -y install #{removed.join(' ')}") unless removed.empty?
        end
      end

      # On a fresh node the Sicura console previews the module with
      # `puppet apply --noop`, which must not error. A bare include manages
      # only the packages, so the preview enforces simp:defaults, as a SIMP
      # site would. The firewall stays off: simp_firewalld cannot preview a
      # zone that no real run has created yet (see noop_manifest).
      it 'previews simp:defaults on the server without errors' do
        # syslog follows simp_options::syslog, not the profile; turn it on so
        # the preview covers inserting the SYSLOG appender into logback.xml
        set_simp_defaults_hieradata_on(master, 'pupmod::master::syslog' => true)
        result = apply_manifest_on(master, "class { 'pupmod::master': firewall => false }", catch_failures: true, noop: true)
        # Guards against the preview quietly covering the packages alone if the
        # Compliance Engine layer stops resolving the profile
        expect(result.output).to match(%r{Hocon_setting\[pupmod::master webserver.conf webserver.base.ssl-port\].*\(noop\)})
        expect(result.output).to match(%r{Ini_subsetting\[pupmod::master::sysconfig JAVA_ARGS -Xmx\].*\(noop\)})
        expect(result.output).to match(%r{Service\[puppetserver\].*\(noop\)})
        expect(result.output).to match(%r{Augeas\[pupmod::master logback.xml SYSLOG appender\].*\(noop\)})
      end

      it 'applies the master manifest' do
        set_simp_defaults_hieradata_on(master)
        apply_manifest_on(master, master_manifest, accept_all_exit_codes: true)
        apply_manifest_on(master, master_manifest, accept_all_exit_codes: true)
        wait_for_generate_types(master)
      end

      it 'has selinux-policy-targeted-extra installed on EL10+' do
        os_maj = fact_on(master, 'os.release.major').to_i

        skip('Only relevant on EL10+') if os_maj < 10

        on(master, 'rpm -q selinux-policy-targeted-extra')
      end

      it 'has the puppet semodule installed' do
        on(master, 'semodule -l | grep -i puppet')
      end

      it 'is idempotent' do
        apply_manifest_on(master, master_manifest, catch_changes: true)
      end

      it 'runs the CA as its own server on port 8141' do
        webserver = on(master, 'cat /etc/puppetlabs/puppetserver/conf.d/webserver.conf').stdout
        expect(webserver).to match(%r{^\s*base\s*[:\{]})
        expect(webserver).to match(%r{^\s*ca\s*[:\{]})
        on(master, "ss -ltn | grep -E ':8141\\s'")
        on(master, "ss -ltn | grep -E ':8140\\s'")
      end

      # simp:defaults allows TLSv1.3 and TLSv1.2, with only the FIPS-approved
      # TLS 1.3 suites
      [8140, 8141].each do |port|
        it "negotiates TLS 1.3 and TLS 1.2 on port #{port}, but not ChaCha20" do
          ssl = ['hostcert', 'hostprivkey', 'localcacert'].map { |s| on(master, "puppet config print #{s}").stdout.strip }
          s_client = "openssl s_client -brief -connect localhost:#{port} -cert #{ssl[0]} -key #{ssl[1]} -CAfile #{ssl[2]}"

          result = on(master, "#{s_client} -tls1_3 < /dev/null 2>&1")
          expect(result.stdout).to match(%r{^Protocol version: TLSv1\.3$})
          expect(result.stdout).to match(%r{^Ciphersuite: TLS_AES_(256|128)_GCM_SHA(384|256)$})

          result = on(master, "#{s_client} -tls1_2 < /dev/null 2>&1")
          expect(result.stdout).to match(%r{^Protocol version: TLSv1\.2$})

          result = on(master, "#{s_client} -tls1_3 -ciphersuites TLS_CHACHA20_POLY1305_SHA256 < /dev/null 2>&1", accept_all_exit_codes: true)
          expect(result.stdout).not_to match(%r{^Protocol version: TLSv1\.3$})
        end
      end

      it 'serves a catalog to its own agent' do
        on(master, 'puppet agent -t', acceptable_exit_codes: [0, 2])
      end

      it 'is running the JRuby that ships with its openvox-server major' do
        # openvox-server 8 runs JRuby 9.4; openvox-server 9 runs JRuby 10
        server_major = on(master, "rpm -q --qf '%{VERSION}' openvox-server").stdout.split('.').first.to_i
        expected_jruby = (server_major >= 9) ? 'jruby 10' : 'jruby 9'

        result = on(master, 'puppetserver ruby --version')
        expect(result.stdout).to include(expected_jruby)
      end

      context 'when using puppetserver gems' do
        it 'has hiera-eyaml available' do
          result = on(master, 'puppetserver gem list --local hiera-eyaml')
          expect(result.stdout).to include('hiera-eyaml')
        end
      end

      context 'when selinux is enforcing' do
        before(:all) do
          # Make sure SELinux is enabled at boot (not just runtime)
          on(master, "grep -q '^SELINUX=' /etc/selinux/config && sed -ri 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config || echo 'SELINUX=enforcing' >> /etc/selinux/config")

          # Runtime switch (works if kernel not booted with selinux=0)
          on(master, 'setenforce 1', acceptable_exit_codes: [0])

          # Sanity
          result = on(master, 'getenforce')
          raise "SELinux not enforcing: #{result.output}" unless result.output.strip == 'Enforcing'
        end

        it 'sets puppetagent_manage_all_files sebool properly' do
          apply_manifest_on(master, master_manifest, catch_errors: true)
        end

        def sebool_present?(host, name)
          r = on(host, "getsebool -a | awk '{print $1}' | grep -Fx #{name}", acceptable_exit_codes: [0, 1])
          r.exit_code == 0
        end

        it 'has puppetagent_manage_all_files boolean available' do
          expect(sebool_present?(master, 'puppetagent_manage_all_files')).to be(true)
        end
      end

      context 'when managing facter.conf' do
        let(:disable_block_hieradata) do
          { 'pupmod::facter_options' => { 'facts' => { 'blocklist' => ['hypervisors'] } } }
        end

        # An empty section removes it
        let(:enable_block_hieradata) do
          { 'pupmod::facter_options' => { 'facts' => {} } }
        end

        # rubocop:disable-next RSpec/RepeatedExample
        it 'provides hypervisors facts initially' do
          hypervisors = fact_on(master, 'hypervisors')
          exists = !(hypervisors.nil? || hypervisors.empty?)
          expect(exists).to be true
        end

        it 'creates config to disable hypervisors fact block' do
          set_simp_defaults_hieradata_on(master, disable_block_hieradata)
          apply_manifest_on(master, master_manifest, accept_all_exit_codes: true)
        end

        # rubocop:disable-next RSpec/RepeatedDescription, RSpec/RepeatedExample
        it 'is idempotent' do
          apply_manifest_on(master, master_manifest, catch_changes: true)
        end

        it 'no longer provides hypervisors facts' do
          hypervisors = fact_on(master, 'hypervisors')
          exists = !(hypervisors.nil? || hypervisors.empty?)
          expect(exists).to be false
        end

        it 'creates config to re-enable hypervisors fact block' do
          set_simp_defaults_hieradata_on(master, enable_block_hieradata)
          apply_manifest_on(master, master_manifest, accept_all_exit_codes: true)
        end

        # rubocop:disable-next RSpec/RepeatedDescription, RSpec/RepeatedExample
        it 'is idempotent' do
          apply_manifest_on(master, master_manifest, catch_changes: true)
        end

        # rubocop:disable-next RSpec/RepeatedExample
        it 'provides hypervisors facts again' do
          hypervisors = fact_on(master, 'hypervisors')
          exists = !(hypervisors.nil? || hypervisors.empty?)
          expect(exists).to be true
        end
      end
    end
  end
end
