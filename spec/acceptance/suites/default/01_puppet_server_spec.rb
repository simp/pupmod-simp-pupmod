require 'spec_helper_acceptance'

describe 'install environment via r10k and openvox-server' do
  require_relative('lib/util')

  include GenerateTypesTestUtil

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
  # all the first-run noop check needs.
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

        repo_content = <<~REPO
          [openvox-release]
          name=Openvox
          baseurl=https://yum.voxpupuli.org/openvox8/el/#{os_maj}/#{architecture}/
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

          apply_manifest_on(master, noop_manifest, catch_failures: true, noop: true)
        ensure
          # Leave the SUT as we found it: the following examples assume the
          # original enforcement mode, and a leaked `Enforcing` would change the
          # conditions of the first real apply.
          on(master, "setenforce #{(original_mode == 'Enforcing') ? '1' : '0'}", accept_all_exit_codes: true)
          on(master, "dnf -y install #{removed.join(' ')}") unless removed.empty?
        end
      end

      it 'applies the master manifest' do
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

      it 'is running jruby 9' do
        result = on(master, 'puppetserver ruby --version')
        expect(result.stdout).to include('jruby 9')
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
          <<~EOS
            pupmod::manage_facter_conf: true
            pupmod::facter_options:
              facts:
                blocklist:
                  - hypervisors
          EOS
        end

        let(:enable_block_hieradata) { 'pupmod::manage_facter_conf: true' }

        # rubocop:disable RSpec/RepeatedExample
        it 'provides hypervisors facts initially' do
          hypervisors = fact_on(master, 'hypervisors')
          exists = !(hypervisors.nil? || hypervisors.empty?)
          expect(exists).to be true
        end
        # rubocop:enable RSpec/RepeatedExample

        it 'creates config to disable hypervisors fact block' do
          set_hieradata_on(master, disable_block_hieradata)
          apply_manifest_on(master, master_manifest, accept_all_exit_codes: true)
        end

        # rubocop:disable RSpec/RepeatedDescription, RSpec/RepeatedExample
        it 'is idempotent' do
          apply_manifest_on(master, master_manifest, catch_changes: true)
        end
        # rubocop:enable RSpec/RepeatedDescription, RSpec/RepeatedExample

        it 'no longer provides hypervisors facts' do
          hypervisors = fact_on(master, 'hypervisors')
          exists = !(hypervisors.nil? || hypervisors.empty?)
          expect(exists).to be false
        end

        it 'creates config to re-enable hypervisors fact block' do
          set_hieradata_on(master, enable_block_hieradata)
          apply_manifest_on(master, master_manifest, accept_all_exit_codes: true)
        end

        # rubocop:disable RSpec/RepeatedDescription, RSpec/RepeatedExample
        it 'is idempotent' do
          apply_manifest_on(master, master_manifest, catch_changes: true)
        end
        # rubocop:enable RSpec/RepeatedDescription, RSpec/RepeatedExample

        # rubocop:disable RSpec/RepeatedExample
        it 'provides hypervisors facts again' do
          hypervisors = fact_on(master, 'hypervisors')
          exists = !(hypervisors.nil? || hypervisors.empty?)
          expect(exists).to be true
        end
        # rubocop:enable RSpec/RepeatedExample
      end
    end
  end
end
