require 'spec_helper'

describe 'pupmod::master::generate_types' do
  shared_examples_for 'generate_types tests' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_file('/usr/local/sbin/simp_generate_types').that_notifies('Exec[simp_generate_types]') }
    it { is_expected.to create_exec('simp_generate_types') }
    it { is_expected.to create_incron__system_table('simp_generate_types') }
    it {
      custom_content = catalogue.resource('Incron::System_table[simp_generate_types]')[:custom_content]

      expect(custom_content.strip).to eq(valid_output)
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts){ os_facts }

      context 'with default input' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file('/usr/local/sbin/simp_generate_types').with_ensure('absent') }
        it { is_expected.not_to contain_exec('simp_generate_types') }
        it { is_expected.to contain_incron__system_table('simp_generate_types').with_enable(false) }
      end

      context 'when enabling generate_types' do
        let(:params){{
            :enable => true
        }}
        let(:valid_output){[
          '/opt/puppetlabs/server/apps/puppetserver/bin IN_MODIFY,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p all -s -d 30',
          '/opt/puppetlabs/puppet/bin/puppet IN_MODIFY,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p all -s -d 30',
          '/etc/puppetlabs/code/environments IN_MODIFY,IN_CREATE,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p $@/$# -s -d 30',
          '/etc/puppetlabs/code/environments/*/modules IN_MODIFY,IN_CREATE,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p $@/$# -s -d 30',
          '/etc/puppetlabs/code/environments/*/modules/*/lib/puppet/type IN_MODIFY,IN_CREATE,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p $@/$# -s -d 30'
        ].join("\n")}

        it_behaves_like 'generate_types tests'
      end

      context 'when disabling puppetserver triggers with generate_types enabled' do
        let(:params){{
          :enable => true,
          :trigger_on_puppetserver_update => false
        }}

        let(:valid_output){[
          '/opt/puppetlabs/puppet/bin/puppet IN_MODIFY,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p all -s -d 30',
          '/etc/puppetlabs/code/environments IN_MODIFY,IN_CREATE,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p $@/$# -s -d 30',
          '/etc/puppetlabs/code/environments/*/modules IN_MODIFY,IN_CREATE,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p $@/$# -s -d 30',
          '/etc/puppetlabs/code/environments/*/modules/*/lib/puppet/type IN_MODIFY,IN_CREATE,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p $@/$# -s -d 30'
        ].join("\n")}

        it_behaves_like 'generate_types tests'
      end

      context 'when disabling puppet triggers with generate_types enabled' do
        let(:params){{
          :enable => true,
          :trigger_on_puppet_update => false
        }}

        let(:valid_output){[
          '/opt/puppetlabs/server/apps/puppetserver/bin IN_MODIFY,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p all -s -d 30',
          '/etc/puppetlabs/code/environments IN_MODIFY,IN_CREATE,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p $@/$# -s -d 30',
          '/etc/puppetlabs/code/environments/*/modules IN_MODIFY,IN_CREATE,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p $@/$# -s -d 30',
          '/etc/puppetlabs/code/environments/*/modules/*/lib/puppet/type IN_MODIFY,IN_CREATE,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p $@/$# -s -d 30'
        ].join("\n")}

        it_behaves_like 'generate_types tests'
      end

      context 'with a split environmentpath input with generate_types enabled' do
        let(:params){{
            :enable => true
        }}
        let(:facts){
          os_facts.merge({
            :puppet_environmentpath => '/path/one:/path/two'
          })
        }

        let(:valid_output){[
          '/opt/puppetlabs/server/apps/puppetserver/bin IN_MODIFY,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p all -s -d 30',
          '/opt/puppetlabs/puppet/bin/puppet IN_MODIFY,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p all -s -d 30',
          '/path/one IN_MODIFY,IN_CREATE,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p $@/$# -s -d 30',
          '/path/one/*/modules IN_MODIFY,IN_CREATE,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p $@/$# -s -d 30',
          '/path/one/*/modules/*/lib/puppet/type IN_MODIFY,IN_CREATE,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p $@/$# -s -d 30',
          '/path/two IN_MODIFY,IN_CREATE,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p $@/$# -s -d 30',
          '/path/two/*/modules IN_MODIFY,IN_CREATE,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p $@/$# -s -d 30',
          '/path/two/*/modules/*/lib/puppet/type IN_MODIFY,IN_CREATE,IN_NO_LOOP /usr/local/sbin/simp_generate_types -p $@/$# -s -d 30'
        ].join("\n")}

        it_behaves_like 'generate_types tests'
      end
    end
  end
end
