require 'spec_helper'

describe 'pupmod::master::base' do
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
      :ipaddress => '1.2.3.4',
      :interfaces => 'lo,eth0',
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

  shared_examples_for "a fact set base" do
    it { should create_class('pupmod::master::base') }
    it { should contain_user('puppet') }
    it { should contain_group('puppet') }
  end

  describe "RHEL 6" do
    it_behaves_like "a fact set base"
    let(:facts) {base_facts['RHEL 6']}
  end

  describe "RHEL 7" do
    it_behaves_like "a fact set base"
    let(:facts) {base_facts['RHEL 7']}
  end
end
