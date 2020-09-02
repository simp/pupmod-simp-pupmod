require 'spec_helper'
require 'pry'

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

          let(:hieradata) { "sysconfig/#{server_distribution}" }

          if server_distribution == 'PE'
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
          else
            context 'on PC1 with default params' do
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
              let(:hieradata) { "sysconfig/#{server_distribution}_jruby_default" }
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
              let(:hieradata) { "sysconfig/#{server_distribution}_jruby_x" }
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

            context '4CPU 8G system auto-tune' do
              let(:hieradata) { "sysconfig/#{server_distribution}" }
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
                :cpuinfo => {
                  :processor0 => {
                    :vendor_id => "GenuineIntel",
                    :cpu_family => "6",
                    :model => "158",
                    :model_name => "Intel(R) Core(TM) i9-9880H CPU @ 2.30GHz",
                    :stepping => "13",
                    :cpu_MHz => "2304.000",
                    :cache_size => "16384 KB",
                    :physical_id => "0",
                    :siblings => "4",
                    :core_id => "0",
                    :cpu_cores => "4",
                    :apicid => "0",
                    :initial_apicid => "0",
                    :fpu => "yes",
                    :fpu_exception => "yes",
                    :cpuid_level => "22",
                    :wp => "yes",
                    :flags => [
                      "fpu",
                      "vme",
                      "de",
                      "pse",
                      "tsc",
                      "msr",
                      "pae",
                      "mce",
                      "cx8",
                      "apic",
                      "sep",
                      "mtrr",
                      "pge",
                      "mca",
                      "cmov",
                      "pat",
                      "pse36",
                      "clflush",
                      "mmx",
                      "fxsr",
                      "sse",
                      "sse2",
                      "ht",
                      "syscall",
                      "nx",
                      "rdtscp",
                      "lm",
                      "constant_tsc",
                      "rep_good",
                      "nopl",
                      "xtopology",
                      "nonstop_tsc",
                      "eagerfpu",
                      "pni",
                      "pclmulqdq",
                      "ssse3",
                      "cx16",
                      "pcid",
                      "sse4_1",
                      "sse4_2",
                      "x2apic",
                      "movbe",
                      "popcnt",
                      "aes",
                      "xsave",
                      "avx",
                      "rdrand",
                      "hypervisor",
                      "lahf_lm",
                      "abm",
                      "3dnowprefetch",
                      "invpcid_single",
                      "fsgsbase",
                      "avx2",
                      "invpcid",
                      "rdseed",
                      "clflushopt",
                      "md_clear",
                      "flush_l1d",
                      "arch_capabilities"
                    ],
                    :bogomips => "4608.00",
                    :clflush_size => "64",
                    :cache_alignment => "64",
                    :address_sizes => "39 bits physical, 48 bits virtual",
                    :power_management => "power management"
                  },
                  :processor1 => {
                    :vendor_id => "GenuineIntel",
                    :cpu_family => "6",
                    :model => "158",
                    :model_name => "Intel(R) Core(TM) i9-9880H CPU @ 2.30GHz",
                    :stepping => "13",
                    :cpu_MHz => "2304.000",
                    :cache_size => "16384 KB",
                    :physical_id => "0",
                    :siblings => "4",
                    :core_id => "1",
                    :cpu_cores => "4",
                    :apicid => "1",
                    :initial_apicid => "1",
                    :fpu => "yes",
                    :fpu_exception => "yes",
                    :cpuid_level => "22",
                    :wp => "yes",
                    :flags => [
                      "fpu",
                      "vme",
                      "de",
                      "pse",
                      "tsc",
                      "msr",
                      "pae",
                      "mce",
                      "cx8",
                      "apic",
                      "sep",
                      "mtrr",
                      "pge",
                      "mca",
                      "cmov",
                      "pat",
                      "pse36",
                      "clflush",
                      "mmx",
                      "fxsr",
                      "sse",
                      "sse2",
                      "ht",
                      "syscall",
                      "nx",
                      "rdtscp",
                      "lm",
                      "constant_tsc",
                      "rep_good",
                      "nopl",
                      "xtopology",
                      "nonstop_tsc",
                      "eagerfpu",
                      "pni",
                      "pclmulqdq",
                      "ssse3",
                      "cx16",
                      "pcid",
                      "sse4_1",
                      "sse4_2",
                      "x2apic",
                      "movbe",
                      "popcnt",
                      "aes",
                      "xsave",
                      "avx",
                      "rdrand",
                      "hypervisor",
                      "lahf_lm",
                      "abm",
                      "3dnowprefetch",
                      "invpcid_single",
                      "fsgsbase",
                      "avx2",
                      "invpcid",
                      "rdseed",
                      "clflushopt",
                      "md_clear",
                      "flush_l1d",
                      "arch_capabilities"
                    ],
                    :bogomips => "4608.00",
                    :clflush_size => "64",
                    :cache_alignment => "64",
                    :address_sizes => "39 bits physical, 48 bits virtual",
                    :power_management => "power management"
                  },
                  :processor2 => {
                    :vendor_id => "GenuineIntel",
                    :cpu_family => "6",
                    :model => "158",
                    :model_name => "Intel(R) Core(TM) i9-9880H CPU @ 2.30GHz",
                    :stepping => "13",
                    :cpu_MHz => "2304.000",
                    :cache_size => "16384 KB",
                    :physical_id => "0",
                    :siblings => "4",
                    :core_id => "2",
                    :cpu_cores => "4",
                    :apicid => "2",
                    :initial_apicid => "2",
                    :fpu => "yes",
                    :fpu_exception => "yes",
                    :cpuid_level => "22",
                    :wp => "yes",
                    :flags => [
                      "fpu",
                      "vme",
                      "de",
                      "pse",
                      "tsc",
                      "msr",
                      "pae",
                      "mce",
                      "cx8",
                      "apic",
                      "sep",
                      "mtrr",
                      "pge",
                      "mca",
                      "cmov",
                      "pat",
                      "pse36",
                      "clflush",
                      "mmx",
                      "fxsr",
                      "sse",
                      "sse2",
                      "ht",
                      "syscall",
                      "nx",
                      "rdtscp",
                      "lm",
                      "constant_tsc",
                      "rep_good",
                      "nopl",
                      "xtopology",
                      "nonstop_tsc",
                      "eagerfpu",
                      "pni",
                      "pclmulqdq",
                      "ssse3",
                      "cx16",
                      "pcid",
                      "sse4_1",
                      "sse4_2",
                      "x2apic",
                      "movbe",
                      "popcnt",
                      "aes",
                      "xsave",
                      "avx",
                      "rdrand",
                      "hypervisor",
                      "lahf_lm",
                      "abm",
                      "3dnowprefetch",
                      "invpcid_single",
                      "fsgsbase",
                      "avx2",
                      "invpcid",
                      "rdseed",
                      "clflushopt",
                      "md_clear",
                      "flush_l1d",
                      "arch_capabilities"
                    ],
                    :bogomips => "4608.00",
                    :clflush_size => "64",
                    :cache_alignment => "64",
                    :address_sizes => "39 bits physical, 48 bits virtual",
                    :power_management => "power management"
                  },
                  :processor3 => {
                    :vendor_id => "GenuineIntel",
                    :cpu_family => "6",
                    :model => "158",
                    :model_name => "Intel(R) Core(TM) i9-9880H CPU @ 2.30GHz",
                    :stepping => "13",
                    :cpu_MHz => "2304.000",
                    :cache_size => "16384 KB",
                    :physical_id => "0",
                    :siblings => "4",
                    :core_id => "3",
                    :cpu_cores => "4",
                    :apicid => "3",
                    :initial_apicid => "3",
                    :fpu => "yes",
                    :fpu_exception => "yes",
                    :cpuid_level => "22",
                    :wp => "yes",
                    :flags => [
                      "fpu",
                      "vme",
                      "de",
                      "pse",
                      "tsc",
                      "msr",
                      "pae",
                      "mce",
                      "cx8",
                      "apic",
                      "sep",
                      "mtrr",
                      "pge",
                      "mca",
                      "cmov",
                      "pat",
                      "pse36",
                      "clflush",
                      "mmx",
                      "fxsr",
                      "sse",
                      "sse2",
                      "ht",
                      "syscall",
                      "nx",
                      "rdtscp",
                      "lm",
                      "constant_tsc",
                      "rep_good",
                      "nopl",
                      "xtopology",
                      "nonstop_tsc",
                      "eagerfpu",
                      "pni",
                      "pclmulqdq",
                      "ssse3",
                      "cx16",
                      "pcid",
                      "sse4_1",
                      "sse4_2",
                      "x2apic",
                      "movbe",
                      "popcnt",
                      "aes",
                      "xsave",
                      "avx",
                      "rdrand",
                      "hypervisor",
                      "lahf_lm",
                      "abm",
                      "3dnowprefetch",
                      "invpcid_single",
                      "fsgsbase",
                      "avx2",
                      "invpcid",
                      "rdseed",
                      "clflushopt",
                      "md_clear",
                      "flush_l1d",
                      "arch_capabilities"
                    ],
                    :bogomips => "4608.00",
                    :clflush_size => "64",
                    :cache_alignment => "64",
                    :address_sizes => "39 bits physical, 48 bits virtual",
                    :power_management => "power management"
                  }
                }
              })}

              let(:puppetserver_conf) { '/etc/puppetlabs/puppetserver/conf.d/puppetserver.conf' }
              let(:puppetserver_conf_hash) { Hocon.parse(catalogue.resource("File[#{puppetserver_conf}]")['content']) }

              it { binding.pry(); expect(puppetserver_conf_hash['jruby-puppet']['max-active-instances']).to eq(2) }

              it do
                puppetserver_content = File.read("#{File.dirname(__FILE__)}/data/puppetserver-j9-rcc.txt")
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
