require 'spec_helper'

describe 'pupmod::master::sysconfig' do
  on_supported_os.each do |os, os_facts|
    before :all do
      @extras = { :puppet_settings => {
        'master' => {
          'rest_authconfig' => '/etc/puppetlabs/puppet/authconf.conf'
      }}}
    end

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

          let(:pre_condition) {
            %{ service{ #{puppetserver_svc}: } }
          }

          let(:params){{
            :server_distribution => server_distribution
          }}

          if server_distribution == 'PE'
            let(:facts){
              @extras.merge(os_facts).merge(
                :memorysize_mb => '490.16',
                :pe_build      => '2016.1.0'
              )
            }

            it 'sets $tmpdir via a pe_ini_subsetting resource' do
              expect(catalogue).to contain_pe_ini_subsetting('pupmod::master::sysconfig::javatempdir').with(
                'value' => %r{/pserver_tmp$},
                'path'  => '/etc/sysconfig/pe-puppetserver',
              )
            end
          else
            let(:facts){ @extras.merge(os_facts).merge(:memorysize_mb => '490.16') }

            it do
              puppetserver_content = File.read("#{File.dirname(__FILE__)}/data/puppetserver.txt")
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
