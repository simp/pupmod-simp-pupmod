require 'spec_helper_acceptance'

# You can optionally set the SIMP_puppet_generate_types environment variable to
# the number of environments that you would like to process. The default is 100
# environments.

describe 'incron driven puppet generate types'  do
  def wait_for_generate_types(host, timeout=1200, interval=30)
    # Let everything spawn
    sleep(2)

    begin
      require 'timeout'

      Timeout::timeout(1200) do
        done_generating = false
        while !done_generating do
          result = on(host, 'pgrep -f simp_generate_types', :accept_all_exit_codes => true)
          if result.exit_code != 0
            done_generating = true
          else
            puts "Waiting #{interval} seconds"
            sleep(interval)
          end
        end
      end
    rescue => e
      raise(e)
    end
  end

  env_count = ENV.fetch('SIMP_puppet_generate_types', '100').to_i
  env_count = 100 if env_count == 0

  hosts_with_role(hosts, 'simp_master').each do |host|
    context "on #{host}" do
      let(:environment_path) { host.puppet[:environmentpath] }
      let(:resource_types_cache) {
        "#{environment_path}/production/.resource_types"
      }

      it 'should have run `puppet generate types`' do
        wait_for_generate_types(host)

        on(host, "ls -al #{resource_types_cache}")
      end

      it 'should not recreate the resource cache after deletion' do
        on(host, "rm -rf #{resource_types_cache}")
        expect(host.file_exist?(resource_types_cache)).to_not be true
      end

      it 'should create the resource cache in a new environment' do
        on(host, "cp -ra #{environment_path}/production #{environment_path}/new_environment")
        wait_for_generate_types(host)

        on(host, "ls -al #{environment_path}/new_environment/.resource_types")
      end

      it 'should not trigger on removing the .resource_types directories' do
        on(host, "/bin/rm -rf #{environment_path}/*/.resource_types")
      end

      it 'should regenerate *all* resource caches if the puppet binary is updated' do
        on(host, "/bin/echo '' >> /opt/puppetlabs/puppet/bin/puppet")

        wait_for_generate_types(host)

        # This will return 0 if all environments have been generated
        on(host, "ls #{environment_path}/*/.resource_types")
      end

      it 'should not trigger on removing the .resource_types directories' do
        on(host, "/bin/rm -rf #{environment_path}/*/.resource_types")
      end

      it 'should regenerate *all* resource caches if the puppetserver binary is updated' do
        on(host, "/bin/echo '' >> /opt/puppetlabs/server/apps/puppetserver/bin/puppetserver")

        wait_for_generate_types(host)

        # This will return 0 if all environments have been generated
        on(host, "ls #{environment_path}/*/.resource_types")
      end

      it 'should not trigger on removing the .resource_types directories' do
        on(host, "/bin/rm -rf #{environment_path}/*/.resource_types")
      end

      # Validate that we're running the minimal (safe) incron set
      it 'should NOT recreate the resource cache if a library is updated' do
        on(host, "echo '' >> #{environment_path}/production/modules/incron/lib/puppet/type/incron_system_table.rb")
        expect(host.file_exist?(resource_types_cache)).to_not be true
      end

      it "should not crash the system when creating #{env_count} new environments" do
        on(host, "for x in {1..#{env_count}}; do cp -rl #{environment_path}/production #{environment_path}/testenv$x; done")
        wait_for_generate_types(host)

        on(host, "ls #{environment_path} | wc -l")
      end

      it 'should have generated some types on the new environments without locking the system' do
        wait_for_generate_types(host)

        # Success here means that the system did not lock up and at least some
        # types were generated. The Changelog for the relevant version has been
        # updated to cover `puppet generate types` and this is simply a
        # stop-gap to prevent killing systems until we can get to r10k.

        num_generated = on(host, "ls -d #{environment_path}/testenv{1..#{env_count}}/.resource_types 2>/dev/null | wc -l", :accept_all_exit_codes => true).output.lines.last.strip.to_i

        expect(num_generated).to be > 1
      end

      it 'should not crash the system when updating lots of type files' do
        on(host, 'find /etc/puppetlabs/code/environments -path "*/lib/puppet/type/**.rb" -exec echo "# test" >> {} \;')

        wait_for_generate_types(host)

        on(host, "ls #{environment_path} | wc -l")
      end
    end
  end
end
