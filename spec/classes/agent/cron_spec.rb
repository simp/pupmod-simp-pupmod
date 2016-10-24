require 'spec_helper'

describe 'pupmod::agent::cron' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts.merge(
        { :puppet_settings => 
          { :main => 
            { 
              :confdir => '/etc/puppet',
              :environmentpath => '/etc/puppet/environments',
              :logdir => '/var/log/puppet',
              :rundir => '/var/run/puppet',
              :ssldir => '/var/lib/puppet/ssl',
              :vardir => '/var/lib/puppet'
            }
          }
        }) 
      }

      context 'using general parameters' do
        let(:params) {{ :interval => '60' }}

        it { is_expected.to create_class('pupmod::agent::cron') }
        it { is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/-gt 3600/) }
        it { is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(
          /service puppet stop > \/dev\/null 2>&1/
        )}

        it { is_expected.to contain_cron('puppetagent').with({
            'minute'    => ['27','57'],
            'hour'      => '*',
            'monthday'  => '*',
            'month'     => '*',
            'weekday'   => '*'
        })}

        context 'use_alternate_minute_base' do
          let(:params) {{ :minute_base => 'foo' }}
          it { is_expected.to contain_cron('puppetagent').with({
              'minute'    => ['29','59'],
              'hour'      => '*',
              'monthday'  => '*',
              'month'     => '*',
              'weekday'   => '*'
          })}
        end

        context 'set_max_age' do
          let(:params) {{ :maxruntime => '10' }}
          it { is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/-gt 600/) }
        end

        context 'too_short_max_age' do
          let(:params) {{ :maxruntime => '1' }}
          conf_timeout = Puppet.settings[:configtimeout]
          it { is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/-gt #{conf_timeout}/) }
        end
      end
    end
  end
end
