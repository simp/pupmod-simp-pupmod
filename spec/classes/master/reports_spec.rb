require 'spec_helper'

describe 'pupmod::master::reports' do
  base_facts = {
    :operatingsystem => 'RedHat',
    :lsbmajdistrelease => '6',
    :hardwaremodel => 'x86_64',
    :spec_title => description,
    :ipaddress => '1.2.3.4',
    :processorcount => 8,
    :passenger_root => '/usr/lib/ruby/gems/1.8/gems/passenger',
    :passenger_version => '4',
    :trusted => { 'certname' => 'foo.bar.baz' },
    :grub_version => '0.9',
    :uid_min => '500',
    :apache_version => '2.2',
    :init_systems => ['sysv','rc','upstart']
  }

  let(:facts) {base_facts}

  it { should create_file('/etc/cron.daily/puppet_client_report_purge').with_content(/rm -f/) }
end
