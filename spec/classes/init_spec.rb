require 'spec_helper'

describe 'pupmod' do
  base_facts = {
    "RHEL 6" => {
      :apache_version => '2.2',
      :fqdn => 'spec.test',
      :grub_version => '0.97',
      :hardwaremodel => 'x86_64',
      :init_systems => ['sysv','rc','upstart'],
      :interfaces => 'lo,eth0',
      :ipaddress => '1.2.3.4',
      :ipaddress_eth0 => '1.2.3.4',
      :ipaddress_lo => '127.0.0.1',
      :lsbmajdistrelease => '6',
      :operatingsystem => 'RedHat',
      :operatingsystemmajrelease => '6',
      :passenger_root => '/usr/lib/ruby/gems/1.8/gems/passenger',
      :passenger_version => '4',
      :processorcount => 4,
      :selinux_current_mode => 'enabled',
      :trusted => { 'certname' => 'spec.test' },
      :uid_min => '500'
    },
    "RHEL 7" => {
      :apache_version => '2.4',
      :fqdn => 'spec.test',
      :grub_version => '2.02~beta2',
      :hardwaremodel => 'x86_64',
      :init_systems => ['sysv','rc','upstart'],
      :interfaces => 'lo,eth0',
      :ipaddress => '1.2.3.4',
      :ipaddress_eth0 => '1.2.3.4',
      :ipaddress_lo => '127.0.0.1',
      :lsbmajdistrelease => '7',
      :operatingsystem => 'RedHat',
      :operatingsystemmajrelease => '7',
      :passenger_root => '/usr/lib/ruby/gems/1.8/gems/passenger',
      :processorcount => 4,
      :passenger_version => '4',
      :selinux_current_mode => 'enabled',
      :trusted => { 'certname' => 'spec.test' },
      :uid_min => '500'
    }
  }

  shared_examples_for "a fact set init" do
    it { should create_class('pupmod') }
    it { should compile.with_all_deps }
    it { should contain_file('/etc/puppet/puppet.conf') }
    it {
      if facts[:operatingsystemmajrelease].to_i < 7 then
        should contain_selboolean('puppet_manage_all_files')
      else
        should contain_selboolean('puppetagent_manage_all_files')
      end
    }
    it { should_not create_class('pupmod::master') }

    context 'with_selinux_disabled' do
      facts = base_facts[superclass.superclass.description].dup
      facts[:selinux_current_mode] = 'disabled'
      let(:facts) {facts}

      it {
        if facts[:operatingsystemmajrelease].to_i < 7 then
          should_not contain_selboolean('puppet_manage_all_files')
        else
          should_not contain_selboolean('puppetagent_manage_all_files')
        end
      }
    end

    context 'with_master_enabled' do
      let(:params) {{ :enable_puppet_master => true, }}

      it { should create_class('pupmod::master') }
    end
  end

  describe "RHEL 6" do
    it_behaves_like "a fact set init"
    let(:facts) {base_facts['RHEL 6']}
  end

  describe "RHEL 7" do
    it_behaves_like "a fact set init"
    let(:facts) {base_facts['RHEL 7']}
  end
end
