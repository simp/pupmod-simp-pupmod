require 'spec_helper_acceptance'

describe 'incron driven puppet generate types'  do
  hosts_with_role(hosts, 'master').each do |host|
    context "on #{host}" do
      let(:environment_path) { host.puppet[:environmentpath] }
      let(:incron_cache) {
        "#{environment_path}/production/.resource_types"
      }

      it 'should have run `puppet generate types`' do
        # Generate types sleeps for 30 seconds by default
        sleep(35)
        expect(host.file_exist?(incron_cache)).to be true
      end

      it 'should not recreate the resource cache after deletion' do
        on(host, "rm -rf #{incron_cache}")
        expect(host.file_exist?(incron_cache)).to_not be true
      end

      it 'should create the resource cache in a new environment' do
        on(host, "cp -r #{environment_path}/production #{environment_path}/new_environment")
        # Give it some time to generate everything
        sleep(15)
        expect(host.file_exist?("#{environment_path}/new_environment/.resource_types")).to be true
      end

      it 'should recreate the resource cache if a library is updated' do
        on(host, "echo '' >> #{environment_path}/production/modules/incron/lib/puppet/type/incron_system_table.rb")

        # Give it some time to update
        sleep(5)
        expect(host.file_exist?(incron_cache)).to be true
      end
    end
  end
end
