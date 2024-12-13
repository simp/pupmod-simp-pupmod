require 'spec_helper'

describe 'pupmod::master::generate_types' do
  shared_examples_for 'generate_types' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to create_file('/usr/local/sbin/simp_generate_types') }
    it { is_expected.to create_file('/var/run/simp_generate_types') }
    it { is_expected.to create_exec('simp_generate_types').that_requires('File[/usr/local/sbin/simp_generate_types]') }
    it { is_expected.to create_exec('simp_generate_types').that_requires('File[/var/run/simp_generate_types]') }
    it { is_expected.to create_tidy('/etc/incron.d').with_matches('simp_generate_types*') }
  end

  shared_examples_for 'generate_types_systemd' do |content, force_content = nil|
    it { is_expected.to create_systemd__unit_file('simp_generate_types.path').with_enable(true) }
    it { is_expected.to create_systemd__unit_file('simp_generate_types.path').with_active(true) }
    it { is_expected.to create_systemd__unit_file('simp_generate_types.path').with_content(content) }

    if force_content
      force_service_content = <<~EOM
        [Service]
        Type=simple
        ExecStart=/usr/local/sbin/simp_generate_types --syslog --all --batch --timeout 300 --stability_timeout 500 --force
      EOM

      it { is_expected.to create_systemd__unit_file('simp_generate_types_apps.path').with_enable(true) }
      it { is_expected.to create_systemd__unit_file('simp_generate_types_apps.path').with_active(true) }
      it { is_expected.to create_systemd__unit_file('simp_generate_types_apps.path').with_content(force_content) }
      it { is_expected.to create_systemd__unit_file('simp_generate_types_force.service').with_content(force_service_content) }
    else
      it { is_expected.not_to create_systemd__unit_file('simp_generate_types_apps.path') }
      it { is_expected.not_to create_systemd__unit_file('simp_generate_types_force.service') }
    end

    service_content = <<~EOM
      [Service]
      Type=simple
      ExecStart=/usr/local/sbin/simp_generate_types --syslog --all --batch --timeout 300 --stability_timeout 500
    EOM

    it { is_expected.to create_systemd__unit_file('simp_generate_types.service').with_content(service_content) }
  end

  shared_examples_for 'generate_types_incron_deprecated' do
    it { is_expected.to create_notify('simp_generate_types incron deprecated').with_loglevel('warning') }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) do
        os_facts.merge({
                         puppet_environmentpath: '/etc/puppetlabs/code/environments'
                       })
      end

      context 'with default input' do
        systemd_path_content = <<~EOM
          [Install]
          WantedBy=multi-user.target

          [Path]
          Unit=simp_generate_types.service
          PathChanged=/etc/puppetlabs/code/environments
          PathExistsGlob=/etc/puppetlabs/code/environments/*/modules/*/lib/puppet/type/*.rb
        EOM

        systemd_app_content = <<~EOM
          [Install]
          WantedBy=multi-user.target

          [Path]
          Unit=simp_generate_types_force.service
          PathChanged=/opt/puppetlabs/server/apps/puppetserver/bin/puppetserver
          PathChanged=/opt/puppetlabs/puppet/bin/puppet
        EOM

        it_behaves_like 'generate_types'
        if Array(os_facts[:init_systems]).include?('systemd')
          it_behaves_like 'generate_types_systemd', systemd_path_content, systemd_app_content
        else
          it_behaves_like 'generate_types_incron_deprecated'
        end
      end

      context 'when disabling puppetserver triggers' do
        let(:params) do
          {
            trigger_on_puppetserver_update: false
          }
        end

        systemd_path_content = <<~EOM
          [Install]
          WantedBy=multi-user.target

          [Path]
          Unit=simp_generate_types.service
          PathChanged=/etc/puppetlabs/code/environments
          PathExistsGlob=/etc/puppetlabs/code/environments/*/modules/*/lib/puppet/type/*.rb
        EOM

        systemd_app_content = <<~EOM
          [Install]
          WantedBy=multi-user.target

          [Path]
          Unit=simp_generate_types_force.service
          PathChanged=/opt/puppetlabs/puppet/bin/puppet
        EOM

        it_behaves_like 'generate_types'
        if Array(os_facts[:init_systems]).include?('systemd')
          it_behaves_like 'generate_types_systemd', systemd_path_content, systemd_app_content
        else
          it_behaves_like 'generate_types_incron_deprecated'
        end
      end

      context 'when disabling puppet triggers' do
        let(:params) do
          {
            trigger_on_puppet_update: false
          }
        end

        systemd_path_content = <<~EOM
          [Install]
          WantedBy=multi-user.target

          [Path]
          Unit=simp_generate_types.service
          PathChanged=/etc/puppetlabs/code/environments
          PathExistsGlob=/etc/puppetlabs/code/environments/*/modules/*/lib/puppet/type/*.rb
        EOM

        systemd_app_content = <<~EOM
          [Install]
          WantedBy=multi-user.target

          [Path]
          Unit=simp_generate_types_force.service
          PathChanged=/opt/puppetlabs/server/apps/puppetserver/bin/puppetserver
        EOM

        it_behaves_like 'generate_types'
        if Array(os_facts[:init_systems]).include?('systemd')
          it_behaves_like 'generate_types_systemd', systemd_path_content, systemd_app_content
        else
          it_behaves_like 'generate_types_incron_deprecated'
        end
      end

      context 'when disabling puppetserver and puppet triggers' do
        let(:params) do
          {
            trigger_on_puppet_update: false,
         trigger_on_puppetserver_update: false
          }
        end

        systemd_path_content = <<~EOM
          [Install]
          WantedBy=multi-user.target

          [Path]
          Unit=simp_generate_types.service
          PathChanged=/etc/puppetlabs/code/environments
          PathExistsGlob=/etc/puppetlabs/code/environments/*/modules/*/lib/puppet/type/*.rb
        EOM

        it_behaves_like 'generate_types'
        if Array(os_facts[:init_systems]).include?('systemd')
          it_behaves_like 'generate_types_systemd', systemd_path_content
        else
          it_behaves_like 'generate_types_incron_deprecated'
        end
      end

      context 'when disabling environment triggers' do
        let(:params) do
          {
            trigger_on_new_environment: false
          }
        end

        systemd_path_content = <<~EOM
          [Install]
          WantedBy=multi-user.target

          [Path]
          Unit=simp_generate_types.service
          PathExistsGlob=/etc/puppetlabs/code/environments/*/modules/*/lib/puppet/type/*.rb
        EOM

        systemd_app_content = <<~EOM
          [Install]
          WantedBy=multi-user.target

          [Path]
          Unit=simp_generate_types_force.service
          PathChanged=/opt/puppetlabs/server/apps/puppetserver/bin/puppetserver
          PathChanged=/opt/puppetlabs/puppet/bin/puppet
        EOM

        it_behaves_like 'generate_types'
        if Array(os_facts[:init_systems]).include?('systemd')
          it_behaves_like 'generate_types_systemd', systemd_path_content, systemd_app_content
        else
          it_behaves_like 'generate_types_incron_deprecated'
        end
      end

      context 'when disabling type change triggers' do
        let(:params) do
          {
            trigger_on_type_change: false
          }
        end

        systemd_path_content = <<~EOM
          [Install]
          WantedBy=multi-user.target

          [Path]
          Unit=simp_generate_types.service
          PathChanged=/etc/puppetlabs/code/environments
        EOM

        systemd_app_content = <<~EOM
          [Install]
          WantedBy=multi-user.target

          [Path]
          Unit=simp_generate_types_force.service
          PathChanged=/opt/puppetlabs/server/apps/puppetserver/bin/puppetserver
          PathChanged=/opt/puppetlabs/puppet/bin/puppet
        EOM

        it_behaves_like 'generate_types'
        if Array(os_facts[:init_systems]).include?('systemd')
          it_behaves_like 'generate_types_systemd', systemd_path_content, systemd_app_content
        else
          it_behaves_like 'generate_types_incron_deprecated'
        end
      end

      context 'with multiple environment paths' do
        let(:facts) do
          os_facts.merge({
                           puppet_environmentpath: '/etc/puppetlabs/code/environments:/foo/bar/baz'
                         })
        end

        systemd_path_content = <<~EOM
          [Install]
          WantedBy=multi-user.target

          [Path]
          Unit=simp_generate_types.service
          PathChanged=/etc/puppetlabs/code/environments
          PathExistsGlob=/etc/puppetlabs/code/environments/*/modules/*/lib/puppet/type/*.rb
          PathExistsGlob=/foo/bar/baz/*/modules/*/lib/puppet/type/*.rb
        EOM

        systemd_app_content = <<~EOM
          [Install]
          WantedBy=multi-user.target

          [Path]
          Unit=simp_generate_types_force.service
          PathChanged=/opt/puppetlabs/server/apps/puppetserver/bin/puppetserver
          PathChanged=/opt/puppetlabs/puppet/bin/puppet
        EOM

        it_behaves_like 'generate_types'
        if Array(os_facts[:init_systems]).include?('systemd')
          it_behaves_like 'generate_types_systemd', systemd_path_content, systemd_app_content
        else
          it_behaves_like 'generate_types_incron_deprecated'
        end
      end

      context 'when disabled' do
        let(:params) do
          {
            enable: false
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_file('/usr/local/sbin/simp_generate_types') }
        it { is_expected.to create_file('/var/run/simp_generate_types') }
        it { is_expected.not_to create_exec('simp_generate_types') }
        it { is_expected.to create_service('simp_generate_types').with_enable(false) }
        it { is_expected.to create_service('simp_generate_types_force').with_enable(false) }
        if Array(os_facts[:init_systems]).include?('systemd')
          it { is_expected.to create_systemd__unit_file('simp_generate_types.path').with_ensure('absent') }
          it { is_expected.to create_systemd__unit_file('simp_generate_types_apps.path').with_ensure('absent') }
          it { is_expected.to create_systemd__unit_file('simp_generate_types.service').with_ensure('absent') }
          it { is_expected.to create_systemd__unit_file('simp_generate_types_force.service').with_ensure('absent') }
        else
          it { is_expected.not_to create_systemd__unit_file('simp_generate_types.path').with_ensure('absent') }
          it { is_expected.not_to create_systemd__unit_file('simp_generate_types_apps.path').with_ensure('absent') }
          it { is_expected.not_to create_systemd__unit_file('simp_generate_types.service').with_ensure('absent') }
          it { is_expected.not_to create_systemd__unit_file('simp_generate_types_force.service').with_ensure('absent') }
        end
        it { is_expected.to create_tidy('/etc/incron.d').with_matches('simp_generate_types*') }
      end
    end
  end
end
