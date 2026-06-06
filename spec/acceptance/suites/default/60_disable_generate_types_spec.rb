require 'spec_helper_acceptance'

describe 'disable automatic puppet generate types' do
  require_relative('lib/util')

  include GenerateTypesTestUtil

  hosts_with_role(hosts, 'simp_master').each do |host|
    context "on #{host}" do
      let(:environment_path) { host.puppet[:environmentpath] }
      let(:resource_types_cache) do
        "#{environment_path}/production/.resource_types"
      end

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

      let(:hieradata) do
        {
          'pupmod::master::generate_types::enable' => false,
        }
      end

      it 'cleans up the cache' do
        set_hieradata_on(host, hieradata)
        apply_manifest_on(host, master_manifest, accept_all_exit_codes: true)

        on(host, "rm -rf #{resource_types_cache}")
        expect(host.file_exist?(resource_types_cache)).to be false
      end

      it 'does not create the resource cache in a new environment' do
        on(host, "cp -ra #{environment_path}/production #{environment_path}/disabled_environment")
        sleep(11)

        wait_for_generate_types(host)

        expect(host.file_exist?("#{environment_path}/disabled_environment/.resource_types")).to be false
      end
    end
  end
end
