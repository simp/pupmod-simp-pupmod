require 'spec_helper'

describe 'pupmod::master::generate_types' do
  shared_examples_for 'generate_types tests' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_file('/usr/local/sbin/simp_generate_types') }
    it { is_expected.to create_file('/var/run/simp_generate_types') }
    it { is_expected.to create_exec('simp_generate_types').that_requires('File[/usr/local/sbin/simp_generate_types]') }
    it { is_expected.to create_exec('simp_generate_types').that_requires('File[/var/run/simp_generate_types]') }
    it { is_expected.to create_incron__system_table('simp_generate_types').that_requires('File[/usr/local/sbin/simp_generate_types]') }
    it { is_expected.to create_incron__system_table('simp_generate_types').that_requires('File[/var/run/simp_generate_types]') }
    it { is_expected.to create_incron__system_table('simp_generate_types').with_custom_content(%r{/var/run/simp_generate_types .+ /usr/local/sbin/simp_generate_types -d 30 -s -g -p .+}) }
  end

  shared_examples_for 'generate_types_puppetserver' do
    it { is_expected.to create_incron__system_table('simp_generate_types_puppetserver_exe').that_requires('File[/usr/local/sbin/simp_generate_types]') }
    it { is_expected.to create_incron__system_table('simp_generate_types_puppetserver_exe').that_requires('File[/var/run/simp_generate_types]') }
    it { is_expected.to create_incron__system_table('simp_generate_types_puppetserver_exe').with_custom_content(%r{/opt/puppetlabs/server/apps/puppetserver/bin/puppetserver .+ /usr/local/sbin/simp_generate_types -s -p /var/run/simp_generate_types/to_process -m ALL}) }
  end

  shared_examples_for 'generate_types_puppet' do
    it { is_expected.to create_incron__system_table('simp_generate_types_puppet_exe').that_requires('File[/usr/local/sbin/simp_generate_types]') }
    it { is_expected.to create_incron__system_table('simp_generate_types_puppet_exe').that_requires('File[/var/run/simp_generate_types]') }
    it { is_expected.to create_incron__system_table('simp_generate_types_puppet_exe').with_custom_content(%r{/opt/puppetlabs/puppet/bin/puppet .+ /usr/local/sbin/simp_generate_types -s -p /var/run/simp_generate_types/to_process -m ALL}) }
  end

  shared_examples_for 'generate_types_new_environment' do
    it { is_expected.to create_incron__system_table('simp_generate_types_new_environment').that_requires('File[/usr/local/sbin/simp_generate_types]') }
    it { is_expected.to create_incron__system_table('simp_generate_types_new_environment').that_requires('File[/var/run/simp_generate_types]') }
    it { is_expected.to create_incron__system_table('simp_generate_types_new_environment').with_custom_content(%r{/etc/puppetlabs/code/environments IN_CREATE,IN_CLOSE_WRITE,IN_MOVED_TO,IN_ONLYDIR,IN_DONT_FOLLOW,recursive=false /usr/local/sbin/simp_generate_types -s -p /var/run/simp_generate_types/to_process -m .+}) }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts){ os_facts }

      context 'with default input' do
        it_behaves_like 'generate_types tests'
        it_behaves_like 'generate_types_puppetserver'
        it_behaves_like 'generate_types_puppet'
        it_behaves_like 'generate_types_new_environment'
      end

      context 'when disabling puppetserver triggers' do
        let(:params){{
          :trigger_on_puppetserver_update => false
        }}

        it_behaves_like 'generate_types tests'
        it_behaves_like 'generate_types_puppet'
        it_behaves_like 'generate_types_new_environment'
        it { is_expected.to create_incron__system_table('simp_generate_types_puppetserver_exe').with_enable(false) }
      end

      context 'when disabling puppet triggers' do
        let(:params){{
          :trigger_on_puppet_update => false
        }}

        it_behaves_like 'generate_types tests'
        it_behaves_like 'generate_types_puppetserver'
        it_behaves_like 'generate_types_new_environment'
        it { is_expected.to create_incron__system_table('simp_generate_types_puppet_exe').with_enable(false) }
      end

      context 'when disabling environment triggers' do
        let(:params){{
          :trigger_on_new_environment => false
        }}

        it_behaves_like 'generate_types tests'
        it_behaves_like 'generate_types_puppetserver'
        it_behaves_like 'generate_types_puppet'
        it { is_expected.to create_incron__system_table('simp_generate_types_new_environment').with_enable(false) }
      end
    end
  end
end
