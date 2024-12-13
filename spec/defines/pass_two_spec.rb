require 'spec_helper'
require 'yaml'
data = YAML.load_file("#{File.dirname(__FILE__)}/data/moduledata.yaml")

describe 'pupmod::pass_two' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts
      end

      let(:assert_private_shim) do
        <<-EOM
        function assert_private { true }
      EOM
      end

      let(:pre_condition) { assert_private_shim }

      [
        'PC1',
        'PE',
      ].each do |distribution|
        context "with server_distribution = #{distribution}" do
          [
            false,
            true,
          ].each do |pe_included|
            context "with puppet_enterprise in the catalog is #{pe_included}" do
              if pe_included == true
                let(:pre_condition) do
                  <<-EOM
                  #{assert_private_shim}
                  include ::puppet_enterprise
                  EOM
                end
              end
              $pe_mode = if (pe_included == true) || (distribution == 'PE')
                           true
                         else
                           false
                         end
              let(:title) { 'main' }
              let(:params) do
                {
                  server_distribution: distribution
                }
              end

              {
                'server_list' => ['11.22.33.44', '5.6.7.8'],
                'server' => '11.22.33.44'
              }.each do |key, data|
                context "with pupmod_server as #{data}" do
                  if $pe_mode
                    it { is_expected.not_to contain_ini_setting("pupmod_#{key}") }
                  else
                    let(:title) { 'main' }
                    let(:params) do
                      {
                        server_distribution: distribution,
                        pupmod_server: data
                      }
                    end
                    if key == 'server_list'
                      it {
                        is_expected.to contain_pupmod__conf(key).with(
                        {
                          'ensure' => 'present',
                          'setting' => key,
                          'value' => data.join(',')
                        },
                      )
                      }
                      it {
                        is_expected.to contain_pupmod__conf('server').with(
                          {
                            'ensure' => 'absent',
                            'setting' => 'server',
                            'value' => ''
                          },
                        )
                      }
                    else
                      it {
                        is_expected.to contain_pupmod__conf(key).with(
                          {
                            'ensure' => 'present',
                            'setting' => key,
                            'value' => data
                          },
                        )
                      }
                      it {
                        is_expected.to contain_pupmod__conf('server_list').with(
                          {
                            'ensure' => 'absent',
                            'setting' => 'server_list',
                            'value' => ''
                          },
                        )
                      }
                    end
                  end
                end
              end

              {
                'ca_server' => {
                  'value' => '$server'
                },
                'masterport' => {
                  'value' => 8140
                },
                'report' => {
                  'value' => false,
                  'section' => 'agent'
                },
                'ca_port' => {
                  'value' => 8141
                }
              }.each do |key, value|
                if $pe_mode
                  it { is_expected.not_to contain_ini_setting("pupmod_#{key}") }
                else
                  it {
                    is_expected.to contain_pupmod__conf(key).with(
                      {
                        'setting' => key
                      }.merge(value),
                    )
                  }
                  it { is_expected.to contain_ini_setting("pupmod_#{key}") }
                end
              end

              if $pe_mode
                mode = nil
                group = nil
              else
                mode = '0640'
                group = 'puppet'
              end
              it {
                is_expected.to contain_file('/etc/puppetlabs/puppet').with({
                                                                             'ensure' => 'directory',
                'owner'  => 'root',
                'group'  => 'puppet',
                'mode'   => mode,
                                                                           })
              }
              it {
                is_expected.to contain_file('/etc/puppetlabs/puppet/puppet.conf').with({
                                                                                         'ensure' => 'file',
                'owner'  => 'root',
                'group'  => group,
                'mode'   => mode
                                                                                       })
              }
              it {
                is_expected.to contain_group('puppet').with({
                                                              'ensure' => 'present',
                'allowdupe' => false,
                'tag' => 'firstrun',
                                                            })
              }

              if $pe_mode
                classlist = data['pupmod::pe_classlist']
                classlist.each do |key, value|
                  next if ['pupmod', 'pupmod::master'].include?(key)
                  context "when #{key} is included in the catalog" do
                    let(:pre_condition) do
                      ret = if key == 'puppet_enterprise::profile::master'
                              %(
                          #{assert_private_shim}
                          include puppet_enterprise
                          class { 'pupmod':
                            mock => true
                          }
                          include #{key}
                        )
                            else
                              %(
                          #{assert_private_shim}
                          include puppet_enterprise
                          include #{key}
                        )
                            end

                      if defined?(data)
                        _services = []
                        data['pupmod::pe_classlist'].each_pair do |_k, v|
                          _services += v['services'] if v['services']
                        end

                        _services.uniq.each do |_service|
                          ret << %{\nensure_resource('service', '#{_service}')}
                        end
                      end

                      ret
                    end

                    users = value['users']
                    users&.each do |user|
                      it "contains Group[puppet] with user #{user} in the members array" do
                        members = catalogue.resource('group', 'puppet').send(:parameters)[:members]
                        expect(members.find { |x| x =~ Regexp.new(user.to_s) }).to be_truthy
                      end
                    end

                    services = value['services']
                    services&.each do |service|
                      it "contains Group[puppet] that notifies Service[#{service}]" do
                        notify = catalogue.resource('group', 'puppet').send(:parameters)[:notify]
                        regex = Regexp.new(service.to_s)
                        expect(notify.find { |x| x.to_s =~ Regexp.new(regex) }).to be_truthy
                      end
                    end

                    firewall = value['firewall_rules']
                    firewall&.each do |rule|
                      let(:params) do
                        {
                          'firewall' => true
                        }
                      end
                      it { is_expected.to contain_iptables__listen__tcp_stateful("#{key} - #{rule['proto']} - #{rule['port']}").with({ 'dports' => rule['port'] }) }
                    end
                  end
                end
              end

              if $pe_mode
                context 'with pupmod::master defined' do
                  let(:pre_condition) do
                    <<-EOM
                      #{assert_private_shim}
                      include ::puppet_enterprise
                      include ::puppet_enterprise::profile::master
                      class { "::pupmod":
                        mock => true
                      }
                      include pupmod::master
                    EOM
                  end

                  it {
                    is_expected.to compile.and_raise_error(%r{.*pupmod::master is NOT supported on PE masters. Please remove the pupmod::master classification from hiera or the puppet console before proceeding.*})
                  }
                end
                context 'with pupmod::master not defined' do
                  let(:pre_condition) do
                    <<-EOM
                      #{assert_private_shim}
                      include ::puppet_enterprise
                      include ::puppet_enterprise::profile::master
                      class { "::pupmod":
                        mock => true
                      }
                    EOM
                  end

                  it { is_expected.to compile }
                  it { is_expected.to contain_class('pupmod::master::sysconfig') }
                  {
                    '2015.1.1' => true,
                    '2015.20.1' => true,
                    '2016.1.0' => true,
                    '2016.2.0' => true,
                    '2016.4.0' => false,
                    '2016.4.1' => false,
                    '2016.5.1' => false,
                    '2017.1.0' => false,
                    '2017.20.1' => false,
                    '2018.1.0' => false,
                    '2020.1.0' => false,
                    '2021.1.0' => false,
                  }.each do |pe_version, tmpdir|
                    it { is_expected.to contain_file("#{File.dirname(facts[:puppet_settings][:master][:server_datadir])}/pserver_tmp") }

                    context "when pe_version == #{pe_version}" do
                      let(:facts) do
                        { 'pe_build' => pe_version }.merge(facts)
                      end

                      ['JAVA_ARGS', 'JAVA_ARGS_CLI'].each do |setting|
                        if tmpdir == true
                          it { is_expected.to contain_pe_ini_subsetting("pupmod::master::sysconfig::javatempdir for #{setting}") }
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
      end
    end
  end
end
