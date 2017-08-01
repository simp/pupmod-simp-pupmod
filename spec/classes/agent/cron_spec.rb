#
require 'spec_helper'

describe 'pupmod::agent::cron' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do

      let(:facts) { os_facts.merge(:ipaddress => '10.0.2.15') }

      context 'using general parameters' do
        let(:params) {{ :interval => 60 }}

        it { is_expected.to create_class('pupmod::agent::cron') }
        it { is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/-gt 14400/) }
        it { is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(
          /service puppet stop > \/dev\/null 2>&1/
        )}
        it { is_expected.to contain_cron('puppetd').with(
            {
              "ensure" => "absent",
            }
          )
        }
        it { is_expected.to contain_cron('puppetagent').with({
            'minute'    => [27,57],
            'hour'      => '*',
            'monthday'  => '*',
            'month'     => '*',
            'weekday'   => '*'
        })}

        context 'use_alternate_minute_base' do
          let(:params) {{ :minute_base => 'foo' }}
          it { is_expected.to contain_cron('puppetagent').with({
              'minute'    => [29,59],
              'hour'      => '*',
              'monthday'  => '*',
              'month'     => '*',
              'weekday'   => '*'
          })}
        end

        context 'set_max_age' do
          let(:params) {{ :maxruntime => 10 }}
          it { is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/-gt 600/) }
        end

        context 'set_max_age' do
          let(:params) {{ :maxruntime => 10 }}
          it { is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/-gt 600/) }
        end

        context 'disable break_puppet_lock' do
          let(:params) {{ :break_puppet_lock => false }}
          it { is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/handles puppet processes which have been running longer than maxruntime/) }
          it { is_expected.to_not contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/handles forcibly enabling puppet agent/) }
        end
      end
    end
  end
end
