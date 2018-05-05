require 'beaker-rspec'
require 'tmpdir'
require 'yaml'
require 'simp/beaker_helpers'
include Simp::BeakerHelpers

unless ENV['BEAKER_provision'] == 'no'
  hosts.each do |host|
    # Install Puppet
    if host.is_pe?
      install_pe
    else
      install_puppet
    end
  end
end


RSpec.configure do |c|
  # ensure that environment OS is ready on each host
  fix_errata_on hosts

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    begin
      # Install modules and dependencies from spec/fixtures/modules
      copy_fixture_modules_to( hosts )

      # Make sure that the SIMP default environment files are in place if they
      # exist
      hosts.each do |sut|
        environment = on(sut, %q(puppet config print environment)).output.strip

        tgt_path = '/var/simp/environments'

        found = false
        on(sut, %Q(puppet config print modulepath --environment #{environment})).output.strip.split(':').each do |mod_path|
          if on(sut, "ls #{mod_path}/simp_environment 2>/dev/null ", :accept_all_exit_codes => true).exit_code == 0

            unless found
              on(sut, %Q(mkdir -p #{tgt_path}))
            end

            found = true

            on(sut, %Q(cp -r #{mod_path}/simp_environment #{tgt_path}))
            on(sut, %Q(rm -rf #{mod_path}/simp_environment))
          end
        end

        if found
          on(sut, %Q(mv #{tgt_path}/simp_environment #{tgt_path}/#{environment}))
        end
      end

      server = only_host_with_role(hosts, 'server')

      # Generate and install PKI certificates on each SUT
      Dir.mktmpdir do |cert_dir|
        run_fake_pki_ca_on(server, hosts, cert_dir )
        hosts.each{ |sut| copy_pki_to( sut, cert_dir, '/etc/pki/simp-testing' )}
      end

      # add PKI keys
      copy_keydist_to(server)
    rescue StandardError, ScriptError => e
      if ENV['PRY']
        require 'pry'; binding.pry
      else
        raise e
      end
    end
  end
end
