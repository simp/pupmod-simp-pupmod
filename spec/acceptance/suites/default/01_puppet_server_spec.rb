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

  hosts_with_role(hosts, 'simp_master').each do |master|
    context "on #{master}" do
      it 'enables SIMP and SIMP dependencies repos' do
        os_maj = fact_on(master, 'os.release.major')
        architecture = fact_on(master, 'os.architecture')

        repo_content = <<-REPO
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

      it 'applies the master manifest' do
        apply_manifest_on(master, master_manifest, accept_all_exit_codes: true)
        apply_manifest_on(master, master_manifest, accept_all_exit_codes: true)
        wait_for_generate_types(master)
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
