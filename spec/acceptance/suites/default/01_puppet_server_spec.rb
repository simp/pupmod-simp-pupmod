require 'spec_helper_acceptance'

describe 'install environment via r10k and puppetserver' do

  require_relative('lib/util')

  include GenerateTypesTestUtil

  let(:master_manifest) { <<-EOF
    include 'iptables'

    # Set up a puppetserver
    class { 'pupmod::master':
      firewall     => true,
      trusted_nets => ['ALL']
    }

    pupmod::master::autosign { 'All Test Hosts': entry => '*' }

    # Maintain connection to the VM
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

    iptables::listen::tcp_stateful { 'allow_ssh':
      trusted_nets => ['ALL'],
      dports       => 22
    }
    EOF
  }

  hosts_with_role(hosts, 'simp_master').each do |master|
    context "on #{master}" do
      it 'should enable SIMP and SIMP dependencies repos' do
        install_simp_repos(master)

        os_maj = fact_on(master, 'operatingsystemmajrelease').strip

        install_latest_package_on(master, 'epel-release',
          "https://dl.fedoraproject.org/pub/epel/epel-release-latest-#{os_maj}.noarch.rpm")
      end

      it 'should install puppetserver' do
        master.install_package('puppetserver')
      end

      it 'should enable autosigning' do
        on(master, 'puppet config --section master set autosign true')
      end

      it 'should enable trusted_server_facts' do
        on(master, 'puppet config --section master set trusted_server_facts true')
      end

      it 'should correct the permissions' do
        on(master, 'chown -R puppet:puppet /etc/puppetlabs/code')
      end

      it 'should apply the master manifest' do
        apply_manifest_on(master, master_manifest, :accept_all_exit_codes => true)
        wait_for_generate_types(master)
      end

      it 'should be idempotent' do
        apply_manifest_on(master, master_manifest, :catch_changes => true )
      end

      it 'should be running jruby 9' do
        result = on(master, 'puppetserver ruby --version')
        expect(result.stdout).to include('jruby 9')
      end

      context 'when using puppetserver gems' do
        it 'should have hiera-eyaml available' do
          result = on(master, 'puppetserver gem list --local hiera-eyaml')
          expect(result.stdout).to include('hiera-eyaml')
        end
      end

      context 'when managing facter.conf' do
        let(:disable_block_hieradata) {
          <<-EOS
            pupmod::manage_facter_conf: true
            pupmod::facter_options:
              facts:
                blocklist:
                  - hypervisors
          EOS
        }

        let(:enable_block_hieradata) { 'pupmod::manage_facter_conf: true' }

        it 'should provide hypervisors facts initially' do
          hypervisors = fact_on(master, 'hypervisors')
          exists = !(hypervisors.nil? || hypervisors.empty?)
          expect(exists).to be true
        end

        it 'should create config to disable hypervisors fact block' do
          set_hieradata_on(master, disable_block_hieradata)
          apply_manifest_on(master, master_manifest, :accept_all_exit_codes => true)
        end

        it 'should be idempotent' do
          apply_manifest_on(master, master_manifest, :catch_changes => true )
        end

        it 'should no longer provide hypervisors facts' do
          hypervisors = fact_on(master, 'hypervisors')
          exists = !(hypervisors.nil? || hypervisors.empty?)
          expect(exists).to be false
        end

        it 'should create config to re-enable hypervisors fact block' do
          set_hieradata_on(master, enable_block_hieradata)
          apply_manifest_on(master, master_manifest, :accept_all_exit_codes => true)
        end

        it 'should be idempotent' do
          apply_manifest_on(master, master_manifest, :catch_changes => true )
        end

        it 'should provide hypervisors facts again' do
          hypervisors = fact_on(master, 'hypervisors')
          exists = !(hypervisors.nil? || hypervisors.empty?)
          expect(exists).to be true
        end
      end
    end
  end
end
