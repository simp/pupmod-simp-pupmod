require 'spec_helper'

describe 'pupmod::master::generate_types' do
  shared_examples_for 'generate_types' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_file('/usr/local/sbin/simp_generate_types') }
    it { is_expected.to create_file('/var/run/simp_generate_types') }
    it { is_expected.to create_exec('simp_generate_types').that_requires('File[/usr/local/sbin/simp_generate_types]') }
    it { is_expected.to create_exec('simp_generate_types').that_requires('File[/var/run/simp_generate_types]') }
  end

  shared_examples_for 'generate_types_incron' do
    it { is_expected.to create_incron__system_table('simp_generate_types').that_requires('File[/usr/local/sbin/simp_generate_types]') }
    it { is_expected.to create_incron__system_table('simp_generate_types').that_requires('File[/var/run/simp_generate_types]') }
    it { is_expected.to create_incron__system_table('simp_generate_types').with_custom_content(%r{/var/run/simp_generate_types .+ /usr/local/sbin/simp_generate_types -d 30 -s -g -p .+}) }
  end

  shared_examples_for 'generate_types_incron_puppetserver' do
    it { is_expected.to create_incron__system_table('simp_generate_types_puppetserver_exe').that_requires('File[/usr/local/sbin/simp_generate_types]') }
    it { is_expected.to create_incron__system_table('simp_generate_types_puppetserver_exe').that_requires('File[/var/run/simp_generate_types]') }
    it { is_expected.to create_incron__system_table('simp_generate_types_puppetserver_exe').with_custom_content(%r{/opt/puppetlabs/server/apps/puppetserver/bin/puppetserver .+ /usr/local/sbin/simp_generate_types -s -p /var/run/simp_generate_types/to_process -m ALL}) }
  end

  shared_examples_for 'generate_types_incron_puppet' do
    it { is_expected.to create_incron__system_table('simp_generate_types_puppet_exe').that_requires('File[/usr/local/sbin/simp_generate_types]') }
    it { is_expected.to create_incron__system_table('simp_generate_types_puppet_exe').that_requires('File[/var/run/simp_generate_types]') }
    it { is_expected.to create_incron__system_table('simp_generate_types_puppet_exe').with_custom_content(%r{/opt/puppetlabs/puppet/bin/puppet .+ /usr/local/sbin/simp_generate_types -s -p /var/run/simp_generate_types/to_process -m ALL}) }
  end

  shared_examples_for 'generate_types_incron_new_environment' do
    it { is_expected.to create_incron__system_table('simp_generate_types_new_environment').that_requires('File[/usr/local/sbin/simp_generate_types]') }
    it { is_expected.to create_incron__system_table('simp_generate_types_new_environment').that_requires('File[/var/run/simp_generate_types]') }
    it { is_expected.to create_incron__system_table('simp_generate_types_new_environment').with_custom_content(%r{/etc/puppetlabs/code/environments IN_CREATE,IN_CLOSE_WRITE,IN_MOVED_TO,IN_ONLYDIR,IN_DONT_FOLLOW,recursive=false /usr/local/sbin/simp_generate_types -s -p /var/run/simp_generate_types/to_process -m .+}) }
  end

  shared_examples_for 'generate_types_systemd' do |content|
    it { is_expected.to create_systemd__unit_file('simp_generate_types.path').with_enable(true) }
    it { is_expected.to create_systemd__unit_file('simp_generate_types.path').with_active(true) }
    it { is_expected.to create_systemd__unit_file('simp_generate_types.path').with_content(content) }

    service_content = <<-EOM
[Service]
Type=simple
ExecStart=/usr/local/sbin/simp_generate_types -d 30 -s -p ALL
    EOM

    it { is_expected.to create_systemd__unit_file('simp_generate_types.service').with_content(service_content) }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts){
        os_facts.merge({
          :puppet_environmentpath => '/etc/puppetlabs/code/environments'
        })
      }

      context 'with default input' do
        systemd_path_content = <<-EOM
[Path]
Unit=simp_generate_types.service
PathChanged=/opt/puppetlabs/server/apps/puppetserver/bin/puppetserver
PathChanged=/opt/puppetlabs/puppet/bin/puppet
PathChanged=/etc/puppetlabs/code/environments
PathExistsGlob=/etc/puppetlabs/code/environments/*/modules/*/lib/puppet/type/*.rb
        EOM

        it_behaves_like 'generate_types'
        if Array(os_facts[:init_systems]).include?('systemd')
          it_behaves_like 'generate_types_systemd', systemd_path_content
        else
          it_behaves_like 'generate_types_incron_puppetserver'
          it_behaves_like 'generate_types_incron_puppet'
          it_behaves_like 'generate_types_incron_new_environment'
        end
      end

      context 'when disabling puppetserver triggers' do
        let(:params){{
          :trigger_on_puppetserver_update => false
        }}

        systemd_path_content = <<-EOM
[Path]
Unit=simp_generate_types.service
PathChanged=/opt/puppetlabs/puppet/bin/puppet
PathChanged=/etc/puppetlabs/code/environments
PathExistsGlob=/etc/puppetlabs/code/environments/*/modules/*/lib/puppet/type/*.rb
        EOM

        it_behaves_like 'generate_types'
        if Array(os_facts[:init_systems]).include?('systemd')
          it_behaves_like 'generate_types_systemd', systemd_path_content
        else
          it_behaves_like 'generate_types_incron_puppet'
          it_behaves_like 'generate_types_incron_new_environment'
          it { is_expected.to create_incron__system_table('simp_generate_types_puppetserver_exe').with_enable(false) }
        end
      end

      context 'when disabling puppet triggers' do
        let(:params){{
          :trigger_on_puppet_update => false
        }}

        systemd_path_content = <<-EOM
[Path]
Unit=simp_generate_types.service
PathChanged=/opt/puppetlabs/server/apps/puppetserver/bin/puppetserver
PathChanged=/etc/puppetlabs/code/environments
PathExistsGlob=/etc/puppetlabs/code/environments/*/modules/*/lib/puppet/type/*.rb
        EOM

        it_behaves_like 'generate_types'
        if Array(os_facts[:init_systems]).include?('systemd')
          it_behaves_like 'generate_types_systemd', systemd_path_content
        else
          it_behaves_like 'generate_types_incron_puppetserver'
          it_behaves_like 'generate_types_incron_new_environment'
          it { is_expected.to create_incron__system_table('simp_generate_types_puppet_exe').with_enable(false) }
        end
      end

      context 'when disabling environment triggers' do
        let(:params){{
          :trigger_on_new_environment => false
        }}

        systemd_path_content = <<-EOM
[Path]
Unit=simp_generate_types.service
PathChanged=/opt/puppetlabs/server/apps/puppetserver/bin/puppetserver
PathChanged=/opt/puppetlabs/puppet/bin/puppet
PathExistsGlob=/etc/puppetlabs/code/environments/*/modules/*/lib/puppet/type/*.rb
        EOM

        it_behaves_like 'generate_types'
        if Array(os_facts[:init_systems]).include?('systemd')
          it_behaves_like 'generate_types_systemd', systemd_path_content
        else
          it_behaves_like 'generate_types_incron_puppetserver'
          it_behaves_like 'generate_types_incron_puppet'
          it { is_expected.to create_incron__system_table('simp_generate_types_new_environment').with_enable(false) }
        end
      end

      context 'when disabling type change triggers' do
        let(:params){{
          :trigger_on_type_change => false
        }}

        systemd_path_content = <<-EOM
[Path]
Unit=simp_generate_types.service
PathChanged=/opt/puppetlabs/server/apps/puppetserver/bin/puppetserver
PathChanged=/opt/puppetlabs/puppet/bin/puppet
PathChanged=/etc/puppetlabs/code/environments
        EOM

        it_behaves_like 'generate_types'
        if Array(os_facts[:init_systems]).include?('systemd')
          it_behaves_like 'generate_types_systemd', systemd_path_content
        else
          it { skip('Non-systemd systems do not support type change triggers') }
        end
      end

      context 'with multiple environment paths' do
        let(:facts){
          os_facts.merge({
            :puppet_environmentpath => '/etc/puppetlabs/code/environments:/foo/bar/baz'
          })
        }

        systemd_path_content = <<-EOM
[Path]
Unit=simp_generate_types.service
PathChanged=/opt/puppetlabs/server/apps/puppetserver/bin/puppetserver
PathChanged=/opt/puppetlabs/puppet/bin/puppet
PathChanged=/etc/puppetlabs/code/environments
PathExistsGlob=/etc/puppetlabs/code/environments/*/modules/*/lib/puppet/type/*.rb
PathExistsGlob=/foo/bar/baz/*/modules/*/lib/puppet/type/*.rb
        EOM

        it_behaves_like 'generate_types'
        if Array(os_facts[:init_systems]).include?('systemd')
          it_behaves_like 'generate_types_systemd', systemd_path_content
        else
          it { skip('Non-systemd systems do not support type change triggers') }
        end
      end
    end
  end
end
