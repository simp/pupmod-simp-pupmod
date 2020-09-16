require 'spec_helper'

describe 'pupmod::master' do
  on_supported_os.each do |os, os_facts|
    before :all do
      @extras = { :puppet_settings => {
        'master' => {
          'rest_authconfig' => '/etc/puppetlabs/puppet/authconf.conf'
      }}}
    end

    puppetserver_content_without_jruby = File.read("#{File.dirname(__FILE__)}/data/puppetserver.txt")
    context "on #{os}" do

      ['PE', 'PC1'].each do |server_distribution|
        context "server distribution '#{server_distribution}'" do
          let(:puppetserver_svc) {
            svc = 'puppetserver'

            if server_distribution == 'PE'
              svc = 'pe-puppetserver'
            end

            svc
          }

          if server_distribution == 'PE'
            context 'on PE with default params' do
              let(:hieradata) { 'sysconfig/PE' }
            
              let(:facts){
                @extras.merge(os_facts).merge(
                  :memorysize_mb => '490.16',
                  :pe_build      => '2016.1.0'
                )
              }

              it 'sets $tmpdir via a pe_ini_subsetting resource' do
                ['JAVA_ARGS', 'JAVA_ARGS_CLI'].each do |setting|
                  expect(catalogue).to contain_pe_ini_subsetting("pupmod::master::sysconfig::javatempdir for #{setting}").with(
                    'path'    => '/etc/sysconfig/pe-puppetserver',
                    'setting' => setting,
                    'value'   => %r{/pserver_tmp$},
                  )
                end
              end
            end
          else
            context 'on PC1 with default params' do
              let(:hieradata) { 'sysconfig/PC1' }
              let(:facts){ @extras.merge(os_facts).merge({
                :memorysize_mb => '490.16',
                :puppetserver_jruby => {
                  'dir' => '/opt/puppetlabs/server/apps/puppetserver',
                  'jarfiles' => ['x.jar','y.jar', 'jruby-9k.jar']
                  }
                 })
              }
              it do
                puppetserver_content = File.read("#{File.dirname(__FILE__)}/data/puppetserver-j9.txt")
                puppetserver_content.gsub!('%PUPPETSERVER_JAVA_TMPDIR_ROOT%',
                  File.dirname(facts[:puppet_settings][:master][:server_datadir]))

                is_expected.to contain_file('/etc/sysconfig/puppetserver').with( {
                  'owner'   => 'root',
                  'group'   => 'puppet',
                  'mode'    => '0640',
                  'content' => puppetserver_content
                } )
              end

              it { is_expected.to create_class('pupmod::master::sysconfig') }
              it { is_expected.to contain_file("#{File.dirname(facts[:puppet_settings][:master][:server_datadir])}/pserver_tmp").with(
                {
                  'owner'  => 'puppet',
                  'group'  => 'puppet',
                  'ensure' => 'directory',
                  'mode'   => '0750'
                }
              )}
            end
            context 'if jruby9k set to true but file does not exist' do
              let(:hieradata) { 'sysconfig/PC1' }
              let(:facts){ @extras.merge(os_facts).merge({
                :memorysize_mb => '490.16',
                :puppetserver_jruby => {
                  'dir' => '/opt/puppetlabs/server/apps/puppetserver',
                  'jarfiles' => ['x.jar','y.jar']
                  }
                })
              }
              it do
                puppetserver_content_without_jruby.gsub!('%PUPPETSERVER_JAVA_TMPDIR_ROOT%',
                  File.dirname(facts[:puppet_settings][:master][:server_datadir]))

                is_expected.to contain_file('/etc/sysconfig/puppetserver').with( {
                  'owner'   => 'root',
                  'group'   => 'puppet',
                  'mode'    => '0640',
                  'content' => puppetserver_content_without_jruby
                } )
              end
            end

            context 'set jrubyjar set to default ' do
              let(:hieradata) { "sysconfig/PC1_jruby_default" }
              let(:facts){ @extras.merge(os_facts).merge(:memorysize_mb => '490.16') }

              it do
                puppetserver_content_without_jruby.gsub!('%PUPPETSERVER_JAVA_TMPDIR_ROOT%',
                  File.dirname(facts[:puppet_settings][:master][:server_datadir]))

                is_expected.to contain_file('/etc/sysconfig/puppetserver').with( {
                  'owner'   => 'root',
                  'group'   => 'puppet',
                  'mode'    => '0640',
                  'content' => puppetserver_content_without_jruby
                } )
              end
            end
            context 'set jruby jar set and no fact ' do
              let(:hieradata) { "sysconfig/PC1_jruby_x" }
              let(:facts){ @extras.merge(os_facts).merge(:memorysize_mb => '490.16') }

              it do
                puppetserver_content_without_jruby.gsub!('%PUPPETSERVER_JAVA_TMPDIR_ROOT%',
                  File.dirname(facts[:puppet_settings][:master][:server_datadir]))

                is_expected.to contain_file('/etc/sysconfig/puppetserver').with( {
                  'owner'   => 'root',
                  'group'   => 'puppet',
                  'mode'    => '0640',
                  'content' => puppetserver_content_without_jruby
                } )
              end
            end

            context '4CPU 8G memory system auto-tune' do
              let(:hieradata) { "sysconfig/PC1" }
              let(:facts) { @extras.merge(os_facts).merge({
                :memorysize_mb => '8192',
                :processorcount => 4,
                :processors => {
                  :physicalcount => 1,
                  :count => 4,
                  :models => [
                    "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                    "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                    "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                    "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz"
                  ]
                },
                :puppetserver_jruby => {
                  'dir' => '/opt/puppetlabs/server/apps/puppetserver',
                  'jarfiles' => ['x.jar','y.jar', 'jruby-9k.jar']
                }
              })}

              let(:puppetserver_conf) { '/etc/puppetlabs/puppetserver/conf.d/puppetserver.conf' }
              let(:puppetserver_conf_hash) { Hocon.parse(catalogue.resource("File[#{puppetserver_conf}]")['content']) }
              ['monolithic', 'primary', 'compile'].each do |server_type|
                context "as #{server_type} server" do
                  let(:expected_instances) {
                    if server_type == 'compile'
                      mi = 3
                    else
                      mi = 2
                    end
  
                    mi
                  }
                  let(:params) {{
                    :server_type => server_type,
                  }}

                  it { expect(puppetserver_conf_hash['jruby-puppet']['max-active-instances']).to eq(expected_instances) }

                  it do
                    puppetserver_content = File.read("#{File.dirname(__FILE__)}/data/puppetserver-j9-rcc-#{server_type}-48.txt")
                    puppetserver_content.gsub!('%PUPPETSERVER_JAVA_TMPDIR_ROOT%',
                      File.dirname(facts[:puppet_settings][:master][:server_datadir]))

                    is_expected.to contain_file('/etc/sysconfig/puppetserver').with( {
                      'owner'   => 'root',
                      'group'   => 'puppet',
                      'mode'    => '0640',
                      'content' => puppetserver_content
                    } )
                  end

                  it { is_expected.to create_class('pupmod::master::sysconfig') }
                  it { is_expected.to contain_file("#{File.dirname(facts[:puppet_settings][:master][:server_datadir])}/pserver_tmp").with(
                    {
                      'owner'  => 'puppet',
                      'group'  => 'puppet',
                      'ensure' => 'directory',
                      'mode'   => '0750'
                    }
                  )}
                end
              end
            end

            context '16CPU 32G memory system auto-tune' do
              let(:hieradata) { "sysconfig/PC1" }
              let(:facts) { @extras.merge(os_facts).merge({
                :memorysize_mb => '32768',
                :processorcount => 16,
                :processors => {
                  :physicalcount => 4,
                  :count => 16,
                  :models => [
                    "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                    "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                    "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                    "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz"
                  ]
                },
                :puppetserver_jruby => {
                  'dir' => '/opt/puppetlabs/server/apps/puppetserver',
                  'jarfiles' => ['x.jar','y.jar', 'jruby-9k.jar']
                }
              })}

              let(:puppetserver_conf) { '/etc/puppetlabs/puppetserver/conf.d/puppetserver.conf' }
              let(:puppetserver_conf_hash) { Hocon.parse(catalogue.resource("File[#{puppetserver_conf}]")['content']) }
              ['monolithic', 'primary', 'compile'].each do |server_type|
                context "as #{server_type} server" do
                  let(:expected_instances) {
                    if server_type == 'compile'
                      mi = 15
                    elsif server_type == 'monolithic'
                      mi = 11
                    else
                      mi = 4
                    end
  
                    mi
                  }
                  let(:params) {{
                    :server_type => server_type,
                  }}

                  it { expect(puppetserver_conf_hash['jruby-puppet']['max-active-instances']).to eq(expected_instances) }

                  it do
                    puppetserver_content = File.read("#{File.dirname(__FILE__)}/data/puppetserver-j9-rcc-#{server_type}-1632.txt")
                    puppetserver_content.gsub!('%PUPPETSERVER_JAVA_TMPDIR_ROOT%',
                      File.dirname(facts[:puppet_settings][:master][:server_datadir]))

                    is_expected.to contain_file('/etc/sysconfig/puppetserver').with( {
                      'owner'   => 'root',
                      'group'   => 'puppet',
                      'mode'    => '0640',
                      'content' => puppetserver_content
                    } )
                  end

                  it { is_expected.to create_class('pupmod::master::sysconfig') }
                  it { is_expected.to contain_file("#{File.dirname(facts[:puppet_settings][:master][:server_datadir])}/pserver_tmp").with(
                    {
                      'owner'  => 'puppet',
                      'group'  => 'puppet',
                      'ensure' => 'directory',
                      'mode'   => '0750'
                    }
                  )}
                end
              end
            end

            # Ensure users can still override to whatever ridiculous settings they want
            context 'crazy manual tuning overrides' do
              let(:hieradata) { "sysconfig/PC1-tuning_overrides" }
              let(:facts) { @extras.merge(os_facts).merge({
                :memorysize_mb => '32768',
                :processorcount => 16,
                :processors => {
                  :physicalcount => 4,
                  :count => 16,
                  :models => [
                    "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                    "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                    "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                    "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz"
                  ]
                },
                :puppetserver_jruby => {
                  'dir' => '/opt/puppetlabs/server/apps/puppetserver',
                  'jarfiles' => ['x.jar','y.jar', 'jruby-9k.jar']
                }
              })}

              let(:puppetserver_conf) { '/etc/puppetlabs/puppetserver/conf.d/puppetserver.conf' }
              let(:puppetserver_conf_hash) { Hocon.parse(catalogue.resource("File[#{puppetserver_conf}]")['content']) }

              it { expect(puppetserver_conf_hash['jruby-puppet']['max-active-instances']).to eq(24) }

              it do
                puppetserver_content = File.read("#{File.dirname(__FILE__)}/data/puppetserver-j9-tuning_overrides.txt")
                puppetserver_content.gsub!('%PUPPETSERVER_JAVA_TMPDIR_ROOT%',
                  File.dirname(facts[:puppet_settings][:master][:server_datadir]))

                is_expected.to contain_file('/etc/sysconfig/puppetserver').with( {
                  'owner'   => 'root',
                  'group'   => 'puppet',
                  'mode'    => '0640',
                  'content' => puppetserver_content
                } )
              end

              it { is_expected.to create_class('pupmod::master::sysconfig') }
              it { is_expected.to contain_file("#{File.dirname(facts[:puppet_settings][:master][:server_datadir])}/pserver_tmp").with(
                {
                  'owner'  => 'puppet',
                  'group'  => 'puppet',
                  'ensure' => 'directory',
                  'mode'   => '0750'
                }
              )}
            end
          end
        end
      end
    end
  end
end