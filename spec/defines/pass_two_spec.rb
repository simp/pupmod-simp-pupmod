require 'spec_helper'
require 'yaml'
data = YAML.load_file("#{File.dirname(__FILE__)}/data/moduledata.yaml")

describe 'pupmod::pass_two' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts
      end
      [
        'PC1',
        'PE'
      ].each do |distribution|
        context "with server_distribution = #{distribution}" do
          [
            false,
            true
          ].each do |pe_included|
            context "with puppet_enterprise in the catalog is #{pe_included}" do
              if (pe_included == true)
                let(:pre_condition) { 'include ::puppet_enterprise' }
              end
              if (pe_included == true or distribution == 'PE')
                $pe_mode = true
              else
                $pe_mode = false
              end
              let(:title) { "main" }
              let(:params) {
                {
                  :server_distribution => distribution
                }
              }
              {
                'server' => {
                  'value' => '1.2.3.4'
                },
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
                  it { is_expected.to_not contain_ini_setting("pupmod_#{key}") }
                else
                  it {
                    is_expected.to contain_pupmod__conf(key).with(
                      {
                        'setting' => key
                      }.merge(value)
                    )
                  }
                  it { is_expected.to contain_ini_setting("pupmod_#{key}") }
                end

              end
              unless $pe_mode
                mode = '0640'
              else
                mode = nil
              end
              it { is_expected.to contain_file('/etc/puppetlabs/puppet').with({
                'ensure' => 'directory',
                'owner'  => 'root',
                'group'  => 'puppet',
                'mode'   => mode,
              }) }
              it { is_expected.to contain_file('/etc/puppetlabs/puppet/puppet.conf').with({
                'ensure' => 'file',
                'owner'  => 'root',
                'group'  => 'puppet',
                'mode'   => mode
              }) }
              it { is_expected.to contain_group('puppet').with({
                'ensure' => 'present',
                'allowdupe'  => false,
                'gid'  => '52',
                'tag'   => 'firstrun',
              }) }


              if $pe_mode
                classlist = data['pupmod::pe_classlist'];
                classlist.each do |key, value|
                  unless (key == 'pupmod' or key == 'pupmod::master')
                    context "when #{key} is included in the catalog" do
                      let(:pre_condition) {
                        if (key == 'puppet_enterprise::profile::master')
                          ret = %{
                            include puppet_enterprise
                            class { 'pupmod':
                              mock => true
                            }
                            include #{key}
                          }
                        else
                          ret = %{
                            include puppet_enterprise
                            include #{key}
                          }
                        end

                        if defined?(data)
                          _services = []
                          data['pupmod::pe_classlist'].each_pair { |k,v|
                            _services += v['services'] if v['services']
                          }

                          _services.uniq.each do |_service|
                            ret << %{\nensure_resource('service', '#{_service}')}
                          end
                        end

                        ret
                      }

                      users = value['users']
                      unless (users == nil)
                        users.each do |user|
                          it "should contain Group[puppet] with user #{user} in the members array" do
                            members = catalogue.resource('group', 'puppet').send(:parameters)[:members]
                            expect(members.find { |x| x =~ Regexp.new("#{user}")}).to be_truthy
                          end
                        end
                      end

                      services = value['services']
                      unless (services == nil)
                        services.each do |service|
                          it "should contain Group[puppet] that notifies Service[#{service}]" do
                            notify = catalogue.resource('group', 'puppet').send(:parameters)[:notify]
                            regex = Regexp.new("#{service}")
                            expect(notify.find { |x| x.to_s =~ Regexp.new(regex)}).to be_truthy
                          end
                        end
                      end

                      firewall = value['firewall_rules']
                      unless (firewall == nil)
                        firewall.each do |rule|
                          let(:params) {
                            {
                              'firewall' => true
                            }
                          }
                          it { is_expected.to contain_iptables__listen__tcp_stateful("#{key} - #{rule['proto']} - #{rule['port']}").with({ 'dports' => rule['port']})}
                        end
                      end
                    end
                  end
                end
              end

              if $pe_mode
                context "with pupmod::master defined" do
                  let(:pre_condition) {
                    '
                      include ::puppet_enterprise
                      include ::puppet_enterprise::profile::master
                      class { "::pupmod":
                        mock => true
                      }
                      include pupmod::master
                    '
                  }
                  it { is_expected.to compile.and_raise_error(/.*pupmod::master is NOT supported on PE masters. Please remove the pupmod::master classification from hiera or the puppet console before proceeding.*/) }

                end
                context "with pupmod::master not defined" do
                  let(:pre_condition) {
                    '
                      include ::puppet_enterprise
                      include ::puppet_enterprise::profile::master
                      class { "::pupmod":
                        mock => true
                      }
                    '
                  }
                  it { is_expected.to compile }
                  it { is_expected.to contain_class("pupmod::master::sysconfig")}
                  it { is_expected.to contain_class("pupmod::params")}
                  {
                    "2015.1.1" => true,
                    "2015.20.1" => true,
                    "2016.1.0" => true,
                    "2016.2.0" => true,
                    "2016.4.0" => false,
                    "2016.4.1" => false,
                    "2016.5.1" => false,
                    "2017.1.0" => false,
                    "2017.20.1" => false,
                    "2018.1.0" => false,
                    "2020.1.0" => false,
                    "2021.1.0" => false,
                  }.each do |pe_version, tmpdir|
                    it { is_expected.to contain_file("#{File.dirname(facts[:puppet_settings][:master][:server_datadir])}/pserver_tmp")}

                    context "when pe_version == #{pe_version}" do
                      let (:facts) do
                        { "pe_build" => pe_version }.merge(facts)
                      end
                      if (tmpdir == true)
                        it { is_expected.to contain_pe_ini_subsetting("pupmod::master::sysconfig::javatempdir")}
                      else
                        it { is_expected.to_not contain_pe_ini_subsetting("pupmod::master::sysconfig::javatempdir")}
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
