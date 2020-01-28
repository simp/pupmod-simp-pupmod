require 'spec_helper_acceptance'

describe 'disable automatic puppet generate types'  do
  require_relative('lib/util')

  include GenerateTypesTestUtil

  hosts_with_role(hosts, 'simp_master').each do |host|
    context "on #{host}" do
      let(:environment_path) { host.puppet[:environmentpath] }
      let(:resource_types_cache) {
        "#{environment_path}/production/.resource_types"
      }

      let(:hieradata) {{
        'pupmod::master::generate_types::enable' => false
      }}

      it 'should clean up the cache' do
        on(host, "rm -rf #{resource_types_cache}")
        expect(host.file_exist?(resource_types_cache)).to be false
      end

      it 'should not create the resource cache in a new environment' do
        on(host, "cp -ra #{environment_path}/production #{environment_path}/disabled_environment")

        wait_for_generate_types(host)

        expect(host.file_exist?("#{environment_path}/disabled_environment/.resource_types")).to be false
      end
    end
  end
end
