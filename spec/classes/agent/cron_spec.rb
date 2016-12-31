#
require 'spec_helper'

describe 'pupmod::agent::cron' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do

      let(:facts) { os_facts }

      context 'using general parameters' do
        let(:params) {{ :interval => 60 }}

        it { is_expected.to create_class('pupmod::agent::cron') }
        it { is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/-gt 3600/) }
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

        context 'set_max_age to never unlock' do
          let(:params) {{ :maxruntime => 0 }}
          it { is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/"0" == "0"/) }
        end

        context 'when pupmod::splay is true' do
          let(:facts) do
            os_facts.merge({'custom_hiera'=>'pupmod_splay_is_true'})
          end
          let(:params) {{ }}
          splay = Puppet[:splaylimit] + 1800 + 10
          it { is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/-gt #{splay}/) }
        end

        context 'when pupmod::splay is true but maxruntime is disabled' do
          let(:facts) { os_facts.merge( {'custom_hiera'=>'pupmod_splay_is_true'} )}
          let(:params) {{ :maxruntime => 0 }}
          splay = Puppet[:splaylimit] + 10
            it { is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/"0" == "0"/) }
            it { is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/-gt #{splay}/) }
        end
      end
    end
  end
end
