require 'spec_helper'

describe 'pupmod::master' do
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
      :uid_min => '500',
      :operatingsystemrelease => '6',
      :osfamily => 'RedHat',
      :use_fips => true
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
      :uid_min => '500',
      :operatingsystemrelease => '7',
      :osfamily => 'RedHat',
      :use_fips => true
    }
  }

  shared_examples_for "a fact set master" do
    it { should compile.with_all_deps }
    it { should create_class('apache') }
    it { should create_class('pupmod') }
    it { should create_class('pupmod::master') }
    it { should create_class('pupmod::master::base') }
  end

  describe "RHEL 6" do
    it_behaves_like "a fact set master"
    let(:facts) {base_facts['RHEL 6']}
  end

  describe "RHEL 7" do
    it_behaves_like "a fact set master"
    let(:facts) {base_facts['RHEL 7']}
  end
end
