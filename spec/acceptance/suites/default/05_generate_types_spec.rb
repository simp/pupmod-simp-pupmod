require 'spec_helper_acceptance'

describe 'incron driven puppet generate types'  do
  #before(:each) {
    #skip "Awaiting fix for SIMP-5974"
  #}

  hosts_with_role(hosts, 'master').each do |host|
    context "on #{host}" do
      let(:environment_path) { host.puppet[:environmentpath] }
      let(:incron_cache) {
        "#{environment_path}/production/.resource_types"
      }

      it 'should have run `puppet generate types`' do
        # Generate types sleeps for 30 seconds by default
        sleep(35)
        on(host, "ls -al #{incron_cache}")
      end

      it 'should not recreate the resource cache after deletion' do
        on(host, "rm -rf #{incron_cache}")
        expect(host.file_exist?(incron_cache)).to_not be true
      end

      it 'should create the resource cache in a new environment' do
        on(host, "cp -ra #{environment_path}/production #{environment_path}/new_environment")
        # Give it some time to generate everything
        sleep(35)
        on(host, "ls -al #{environment_path}/new_environment/.resource_types")
      end

      # Validate that we're running the minimal (safe) incron set
      it 'should NOT recreate the resource cache if a library is updated' do
        on(host, "echo '' >> #{environment_path}/production/modules/incron/lib/puppet/type/incron_system_table.rb")
        expect(host.file_exist?(incron_cache)).to_not be true
      end

      it 'should not crash the system when creating 100 new environments' do
        on(host, "for x in {1..100}; do cp -rl #{environment_path}/production #{environment_path}/testenv$x; done")
        # Give it some time to calm down (this does generate some load)
        sleep(10)
        on(host, "ls #{environment_path}")
      end

      it 'should have generated types on the new environments' do
        begin
          require 'timeout'

          Timeout::timeout(1200) do
            done_generating = false
            while !done_generating do
              result = on(host, 'pgrep -f simp_generate_types', :accept_all_exit_codes => true)
              if result.exit_code != 0
                done_generating = true
              else
                sleep(30)
              end
            end
          end
        rescue => e
          raise(e)
        end

        # This will return 0 if all environments have been generated
        on(host, "ls #{environment_path}/testenv{1..100}/.resource_types")
      end
    end
  end
end
