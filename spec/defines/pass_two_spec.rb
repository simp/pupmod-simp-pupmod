require 'spec_helper'
require 'yaml'

# pupmod::pe_classlist is no longer module data; the simp:defaults profile
# restores it, so take it from there.
PE_CLASSLIST = YAML.load_file(
  File.expand_path('../../SIMP/compliance_profiles/checks.yaml', __dir__),
)['checks']['simp:defaults.pupmod.pe_classlist']['settings']['value']

describe 'pupmod::pass_two' do
  on_supported_os.to_a.values_at(0, -1).each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:title) { 'main' }

      let(:assert_private_shim) do
        <<~EOM
          function assert_private { true }
        EOM
      end

      let(:pre_condition) { assert_private_shim }

      ['PC1', 'openvox-server'].each do |distribution|
        context "with server_distribution = #{distribution}" do
          context 'with no settings' do
            let(:params) { { server_distribution: distribution } }

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to have_pupmod__conf_resource_count(0) }
            it { is_expected.to have_group_resource_count(0) }
            it { is_expected.to have_file_resource_count(0) }
          end

          context 'with pupmod_server as a String' do
            let(:params) { { server_distribution: distribution, pupmod_server: '11.22.33.44' } }

            it { is_expected.to contain_pupmod__conf('server').with(ensure: 'present', setting: 'server', value: '11.22.33.44') }
            it { is_expected.to contain_pupmod__conf('server_list').with(ensure: 'absent', setting: 'server_list') }
          end

          context 'with pupmod_server as an Array' do
            let(:params) { { server_distribution: distribution, pupmod_server: ['11.22.33.44', '5.6.7.8'] } }

            it { is_expected.to contain_pupmod__conf('server_list').with(ensure: 'present', setting: 'server_list', value: '11.22.33.44,5.6.7.8') }
            it { is_expected.to contain_pupmod__conf('server').with(ensure: 'absent', setting: 'server') }
          end

          context "with pupmod_server => 'absent'" do
            let(:params) { { server_distribution: distribution, pupmod_server: 'absent' } }

            it { is_expected.to contain_pupmod__conf('server').with_ensure('absent') }
            it { is_expected.to contain_pupmod__conf('server_list').with_ensure('absent') }
          end

          {
            'ca_server'  => ['$server', 'main'],
            'masterport' => [8140, 'main'],
            'ca_port'    => [8141, 'main'],
            'report'     => [false, 'agent'],
          }.each do |key, (value, section)|
            context "with pupmod_#{key} => #{value}" do
              let(:params) { { server_distribution: distribution, "pupmod_#{key}": value } }

              it { is_expected.to contain_pupmod__conf(key).with(ensure: 'present', setting: key, section: section, value: value) }
              it { is_expected.to contain_ini_setting("pupmod_#{key}").with(ensure: 'present', section: section) }
            end

            context "with pupmod_#{key} => 'absent'" do
              let(:params) { { server_distribution: distribution, "pupmod_#{key}": 'absent' } }

              it { is_expected.to contain_pupmod__conf(key).with(ensure: 'absent', section: section) }
            end
          end

          context 'with puppet_group set' do
            let(:params) { { server_distribution: distribution, puppet_group: 'puppet' } }

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to contain_group('puppet').with(ensure: 'present', allowdupe: false, tag: 'firstrun', members: nil) }
            it { is_expected.to contain_file('/etc/puppetlabs/puppet').with(ensure: 'directory', owner: 'root', group: 'puppet', mode: '0640') }
            it { is_expected.to contain_file('/etc/puppetlabs/puppet/puppet.conf').with(ensure: 'file', owner: 'root', group: 'puppet', mode: '0640') }
          end
        end
      end

      context 'with server_distribution = PE' do
        context 'with settings that only apply to FOSS servers' do
          let(:params) { { server_distribution: 'PE', pupmod_server: '1.2.3.4', pupmod_ca_port: 8141, pupmod_report: true } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to have_pupmod__conf_resource_count(0) }
        end

        context 'with puppet_group set' do
          let(:params) { { server_distribution: 'PE', puppet_group: 'pe-puppet' } }

          it { is_expected.to contain_group('pe-puppet').with(ensure: 'present', members: nil) }
          it { is_expected.to contain_file('/etc/puppetlabs/puppet').with(group: 'pe-puppet', mode: nil) }
          it { is_expected.to contain_file('/etc/puppetlabs/puppet/puppet.conf').with(group: nil, mode: nil) }
        end
      end

      context 'with puppet_enterprise in the catalog' do
        let(:pre_condition) do
          <<~EOM
            #{assert_private_shim}
            include puppet_enterprise
          EOM
        end

        context 'with FOSS settings' do
          let(:params) { { server_distribution: 'PC1', pupmod_server: '1.2.3.4' } }

          it { is_expected.not_to contain_pupmod__conf('server') }
        end

        context 'without pe_classlist' do
          let(:params) { { server_distribution: 'PC1', puppet_group: 'puppet' } }

          it { is_expected.to compile.with_all_deps }
          it 'leaves the group members alone' do
            is_expected.to contain_group('puppet').with_members(nil)
          end
          it { is_expected.to have_pam__access__rule_resource_count(0) }
        end

        PE_CLASSLIST.each do |klass, data|
          next if ['pupmod', 'pupmod::master', 'puppet_enterprise::profile::master'].include?(klass)

          context "with #{klass} in the catalog and pe_classlist supplied" do
            let(:params) do
              {
                server_distribution: 'PE',
                puppet_group: 'puppet',
                pe_classlist: PE_CLASSLIST,
                firewall: true,
              }
            end

            let(:pre_condition) do
              services = PE_CLASSLIST.values.map { |v| v['services'] }.flatten.compact.uniq
              <<~EOM
                #{assert_private_shim}
                include puppet_enterprise
                include #{klass}
                #{services.map { |s| "ensure_resource('service', '#{s}')" }.join("\n")}
              EOM
            end

            it { is_expected.to compile }

            data['users']&.each do |user|
              it "contains Group[puppet] with user #{user} in the members array" do
                members = catalogue.resource('group', 'puppet')[:members]
                expect(members).to include(user)
              end
            end

            data['services']&.each do |service|
              it "contains Group[puppet] that notifies Service[#{service}]" do
                notify = Array(catalogue.resource('group', 'puppet')[:notify]).map(&:to_s)
                expect(notify).to include("Service[#{service}]")
              end
            end

            data['firewall_rules']&.each do |rule|
              it { is_expected.to contain_iptables__listen__tcp_stateful("#{klass} - #{rule['proto']} - #{rule['port']}").with_dports(rule['port']) }
            end

            if data['configure_access']
              it { is_expected.to contain_pam__access__rule("Add rule for #{klass}").with_users(data['users']) }
            end
          end
        end

        context 'with puppet_enterprise::profile::master and pupmod::master' do
          let(:pre_condition) do
            <<~EOM
              #{assert_private_shim}
              include puppet_enterprise
              include puppet_enterprise::profile::master
              class { 'pupmod':
                mock => true,
              }
              include pupmod::master
            EOM
          end

          it {
            is_expected.to compile.and_raise_error(
              %r{pupmod::master is NOT supported on PE masters. Please remove the pupmod::master classification from hiera or the puppet console before proceeding},
            )
          }
        end

        context 'with puppet_enterprise::profile::master and not pupmod::master' do
          let(:pre_condition) do
            <<~EOM
              #{assert_private_shim}
              include puppet_enterprise
              include puppet_enterprise::profile::master
              class { 'pupmod':
                mock => true,
              }
            EOM
          end

          it { is_expected.to compile }
          it { is_expected.to contain_class('pupmod::master::sysconfig') }
          it { is_expected.not_to contain_pe_ini_subsetting('pupmod::master::sysconfig::javatempdir for JAVA_ARGS') }

          {
            '2016.2.0' => true,
            '2016.4.0' => false,
            '2021.1.0' => false,
          }.each do |pe_version, tmpdir|
            context "with java_temp_dir set and pe_build == #{pe_version}" do
              let(:facts) { { 'pe_build' => pe_version }.merge(os_facts) }
              let(:hieradata) { 'agent_pe_java_temp_dir' }

              it { is_expected.to contain_file('/opt/puppetlabs/server/data/pserver_tmp') }

              ['JAVA_ARGS', 'JAVA_ARGS_CLI'].each do |setting|
                if tmpdir
                  it { is_expected.to contain_pe_ini_subsetting("pupmod::master::sysconfig::javatempdir for #{setting}").with_value('=/opt/puppetlabs/server/data/pserver_tmp') }
                else
                  it { is_expected.not_to contain_pe_ini_subsetting("pupmod::master::sysconfig::javatempdir for #{setting}") }
                end
              end
            end
          end
        end
      end
    end
  end
end
