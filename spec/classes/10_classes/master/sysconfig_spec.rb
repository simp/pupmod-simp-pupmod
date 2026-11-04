require 'spec_helper'

# rubocop:disable RSpec/MultipleDescribes

describe 'pupmod::master::sysconfig' do
  def setting(name)
    "pupmod::master::sysconfig #{name}"
  end

  def subsetting(setting, option)
    "pupmod::master::sysconfig #{setting} #{option}"
  end

  let(:sysconfig) { '/etc/sysconfig/puppetserver' }
  let(:post_condition) { 'include pupmod::master' }

  # 4 GiB of memory
  let(:memory) { { memory: { 'system' => { 'total_bytes' => 4_294_967_296 } } } }

  on_supported_os.to_a.values_at(0, -1).uniq.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts.merge(memory) }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to have_ini_setting_resource_count(0) }
        it { is_expected.to have_ini_subsetting_resource_count(0) }
        it { is_expected.to have_file_resource_count(0) }
      end

      describe 'sysconfig settings' do
        {
          java_bin: ['JAVA_BIN', '/usr/lib/jvm/bin/java', '"/usr/lib/jvm/bin/java"'],
          install_dir: ['INSTALL_DIR', '/opt/puppetlabs/server/apps/puppetserver', '"/opt/puppetlabs/server/apps/puppetserver"'],
          config: ['CONFIG', '/etc/puppetlabs/puppetserver/conf.d', '"/etc/puppetlabs/puppetserver/conf.d"'],
          bootstrap_config: ['BOOTSTRAP_CONFIG', ['/a/services.d/', '/b/services.d/'], '"/a/services.d/,/b/services.d/"'],
          service_stop_retries: ['SERVICE_STOP_RETRIES', 60, 60],
          start_timeout: ['START_TIMEOUT', 120, 120],
        }.each do |param, (name, value, written)|
          context "with #{param} set" do
            let(:params) { { param => value } }

            it { is_expected.to compile.with_all_deps }
            it {
              is_expected.to contain_ini_setting(setting(name)).with(
                ensure: 'present',
                path: sysconfig,
                section: '',
                setting: name,
                value: written,
                key_val_separator: '=',
              ).that_requires('Class[pupmod::master::install]').that_notifies('Class[pupmod::master::service]')
            }
          end

          context "with #{param} => 'absent'" do
            let(:params) { { param => 'absent' } }

            it { is_expected.to contain_ini_setting(setting(name)).with_ensure('absent') }
          end
        end
      end

      describe 'JRUBY_JAR' do
        let(:facts) do
          os_facts.merge(memory).merge(
            puppetserver_jruby: {
              'dir'      => '/opt/puppetlabs/server/apps/puppetserver',
              'jarfiles' => ['x.jar', 'jruby-9k.jar'],
            },
          )
        end

        context 'with an installed jar' do
          let(:params) { { jruby_jar: 'x.jar' } }

          it { is_expected.to contain_ini_setting(setting('JRUBY_JAR')).with(ensure: 'present', value: '"/opt/puppetlabs/server/apps/puppetserver/x.jar"') }
        end

        context 'with a jar that is not installed' do
          let(:params) { { jruby_jar: 'missing.jar' } }

          it { is_expected.to contain_ini_setting(setting('JRUBY_JAR')).with_ensure('absent') }
        end

        context "with 'default'" do
          let(:params) { { jruby_jar: 'default' } }

          it { is_expected.to contain_ini_setting(setting('JRUBY_JAR')).with_ensure('absent') }
        end

        context 'without the puppetserver_jruby fact' do
          let(:facts) { os_facts.merge(memory).reject { |k, _| k.to_s == 'puppetserver_jruby' } }
          let(:params) { { jruby_jar: 'x.jar' } }

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_ini_setting(setting('JRUBY_JAR')).with_ensure('absent') }
        end
      end

      describe 'JVM options' do
        shared_examples 'a JVM option' do |option, value|
          ['JAVA_ARGS', 'JAVA_ARGS_CLI'].each do |name|
            it {
              is_expected.to contain_ini_subsetting(subsetting(name, option)).with(
                ensure: (value == 'absent') ? 'absent' : 'present',
                path: sysconfig,
                section: '',
                setting: name,
                subsetting: option,
                value: value,
                quote_char: '"',
              ).that_requires('Class[pupmod::master::install]')
            }
          end
        end

        context 'with java_max_memory' do
          let(:params) { { java_max_memory: '2g' } }

          it_behaves_like 'a JVM option', '-Xmx', '2g'
          # -Xms follows -Xmx when it isn't set
          it_behaves_like 'a JVM option', '-Xms', '2g'
        end

        context 'with java_max_memory and java_start_memory' do
          let(:params) { { java_max_memory: '2g', java_start_memory: '1g' } }

          it_behaves_like 'a JVM option', '-Xmx', '2g'
          it_behaves_like 'a JVM option', '-Xms', '1g'
        end

        context 'with a percentage for java_max_memory' do
          let(:params) { { java_max_memory: '50%' } }

          it_behaves_like 'a JVM option', '-Xmx', '2048m'
        end

        context 'with only java_start_memory' do
          let(:params) { { java_start_memory: '1g' } }

          it_behaves_like 'a JVM option', '-Xms', '1g'
          it { is_expected.not_to contain_ini_subsetting(subsetting('JAVA_ARGS', '-Xmx')) }
        end

        context "with java_max_memory => 'absent'" do
          let(:params) { { java_max_memory: 'absent' } }

          it_behaves_like 'a JVM option', '-Xmx', 'absent'
          it_behaves_like 'a JVM option', '-Xms', 'absent'
        end

        context 'with java_temp_dir' do
          let(:params) { { java_temp_dir: '/opt/pserver_tmp' } }

          it_behaves_like 'a JVM option', '-Djava.io.tmpdir', '=/opt/pserver_tmp'
          it { is_expected.to contain_file('/opt/pserver_tmp').with(ensure: 'directory', owner: 'puppet', group: 'puppet', mode: '0750') }
        end

        context "with java_temp_dir => 'absent'" do
          let(:params) { { java_temp_dir: 'absent' } }

          it_behaves_like 'a JVM option', '-Djava.io.tmpdir', 'absent'
          it { is_expected.not_to contain_file('absent') }
        end

        context 'with use_code_cache_flushing => true' do
          let(:params) { { use_code_cache_flushing: true } }

          it_behaves_like 'a JVM option', '-XX:+UseCodeCacheFlushing', ''
          it_behaves_like 'a JVM option', '-XX:-UseCodeCacheFlushing', 'absent'
        end

        context 'with use_code_cache_flushing => false' do
          let(:params) { { use_code_cache_flushing: false } }

          it_behaves_like 'a JVM option', '-XX:-UseCodeCacheFlushing', ''
          it_behaves_like 'a JVM option', '-XX:+UseCodeCacheFlushing', 'absent'
        end

        context 'with reserved_code_cache' do
          let(:params) { { reserved_code_cache: 512 } }

          it_behaves_like 'a JVM option', '-XX:ReservedCodeCacheSize', '=512m'
        end

        [0, 'absent'].each do |value|
          context "with reserved_code_cache => #{value.inspect}" do
            let(:params) { { reserved_code_cache: value } }

            it_behaves_like 'a JVM option', '-XX:ReservedCodeCacheSize', 'absent'
          end
        end

        context 'with java_redhat_fips => false' do
          let(:params) { { java_redhat_fips: false } }

          it_behaves_like 'a JVM option', '-Dcom.redhat.fips', '=false'
        end

        context "with java_redhat_fips => 'absent'" do
          let(:params) { { java_redhat_fips: 'absent' } }

          it_behaves_like 'a JVM option', '-Dcom.redhat.fips', 'absent'
        end

        context 'with extra_java_args' do
          let(:params) { { extra_java_args: ['-Dfoo=bar', '-XX:+UseG1GC'] } }

          it_behaves_like 'a JVM option', '-Dfoo=bar', ''
          it_behaves_like 'a JVM option', '-XX:+UseG1GC', ''
        end
      end
    end
  end
end

describe 'pupmod::master' do
  # 4 GiB of memory, 8 CPUs
  let(:memory) { { memory: { 'system' => { 'total_bytes' => 4_294_967_296 } }, processors: { 'count' => 8 } } }

  on_supported_os.to_a.values_at(0, -1).uniq.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts.merge(memory) }

      context "with java_max_memory and reserved_code_cache => 'auto'" do
        let(:hieradata) { 'master_sysconfig_auto' }

        it { is_expected.to compile.with_all_deps }
        # 80% of 4 GiB limits pupmod::java_max_memory(pupmod::max_active_instances())
        it { is_expected.to contain_ini_subsetting('pupmod::master::sysconfig JAVA_ARGS -Xmx').with_value(%r{^\d+m$}) }
        it { is_expected.to contain_ini_subsetting('pupmod::master::sysconfig JAVA_ARGS -Xms').with_value(%r{^\d+m$}) }
        # Less than 8 GiB of memory means no reserved code cache
        it { is_expected.to contain_ini_subsetting('pupmod::master::sysconfig JAVA_ARGS -XX:ReservedCodeCacheSize').with_ensure('absent') }
      end

      context "with java_max_memory => 'auto' and max_active_instances" do
        let(:hieradata) { 'master_sysconfig_auto_instances' }

        # 3 instances at 768 MB each with 8 CPUs
        it { is_expected.to contain_ini_subsetting('pupmod::master::sysconfig JAVA_ARGS -Xmx').with_value('2304m') }
      end

      context 'on PE' do
        let(:hieradata) { 'master_sysconfig_pe' }
        let(:facts) { os_facts.merge(memory).merge(pe_build: '2016.1.0') }

        it { is_expected.to compile }
        it { is_expected.to have_ini_setting_resource_count(0) }
        it { is_expected.to have_ini_subsetting_resource_count(0) }
        it { is_expected.to contain_file('/opt/pserver_tmp').with_ensure('directory') }

        ['JAVA_ARGS', 'JAVA_ARGS_CLI'].each do |name|
          it {
            is_expected.to contain_pe_ini_subsetting("pupmod::master::sysconfig::javatempdir for #{name}").with(
              ensure: 'present',
              path: '/etc/sysconfig/pe-puppetserver',
              setting: name,
              value: '=/opt/pserver_tmp',
            )
          }
        end
      end
    end
  end
end
# rubocop:enable RSpec/MultipleDescribes
