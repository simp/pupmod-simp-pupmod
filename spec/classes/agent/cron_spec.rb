require 'spec_helper'

describe 'pupmod::agent::cron' do
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
      :osfamily => 'RedHat'
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
      :osfamily => 'RedHat'
    }
  }

  shared_examples_for "a fact set cron" do
    let(:params) {{ :interval => '60' }}

    it do
      should contain_cron('puppetagent').with({
        'minute'    => ['10','40'],
        'hour'      => '*',
        'monthday'  => '*',
        'month'     => '*',
        'weekday'   => '*'
      })
    end

    it { should create_class('pupmod::agent::cron') }
    it { should contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/-gt 3600/) }

    context 'use_alternate_minute_base' do
      let(:params) {{ :minute_base => 'foo' }}

      it do
        should contain_cron('puppetagent').with({
          'minute'    => ['29','59'],
          'hour'      => '*',
          'monthday'  => '*',
          'month'     => '*',
          'weekday'   => '*'
        })
      end
    end

    context 'set_max_age' do
      let(:params) {{ :maxruntime => '10' }}

      it { should contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/-gt 600/) }
    end

    context 'too_short_max_age' do
      let(:params) {{ :maxruntime => '1' }}

      conf_timeout = Puppet.settings[:configtimeout]

      it { should contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/-gt #{conf_timeout}/) }
    end
  end

  describe "RHEL 6" do
    it_behaves_like "a fact set cron"
    let(:facts) {base_facts['RHEL 6']}
  end

  describe "RHEL 7" do
    it_behaves_like "a fact set cron"
    let(:facts) {base_facts['RHEL 7']}
  end
end
