require 'spec_helper_acceptance'

describe 'install environment via r10k and puppetserver' do

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

  hosts_with_role(hosts, 'master').each do |master|
    context "on #{master}" do
      it 'should install puppetserver' do
        master.install_package('puppetserver')
      end

      it 'should enable autosigning' do
        on(master, 'puppet config --section master set autosign true')
      end

      it 'should enable trusted_server_facts' do
        on(master, 'puppet config --section master set trusted_server_facts true')
      end

      it 'should apply the master manifest' do
        apply_manifest_on(master, master_manifest, :accept_all_exit_codes => true)
        # Work around incron bug
        apply_manifest_on(master, master_manifest, :accept_all_exit_codes => true)
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
    end
  end
end
