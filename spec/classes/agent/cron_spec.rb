#
require 'spec_helper'

describe 'pupmod::agent::cron' do

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do

      let(:facts) { os_facts.merge(:ipaddress => '10.0.2.15') }

      context 'with default parameters' do
        it { is_expected.to create_class('pupmod::agent::cron') }
        it { is_expected.to contain_cron('puppetd').with_ensure("absent") }
        it { is_expected.to contain_cron('puppetagent').with({
          'command'   => '/usr/local/bin/puppetagent_cron.sh',
          'minute'    => [27,57],
          'hour'      => '*',
          'monthday'  => '*',
          'month'     => '*',
          'weekday'   => '*'
        })}

        it 'uses maxruntime to kill processes in puppetagent_cron.sh' do
          expected = Regexp.escape('if [[ -n "${pup_status}" && $(( ${now} - ${filedate} )) -gt 1440')
          is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/#{expected}/)
        end

        it 'includes code to break an existing puppet lock in puppetagent_cron.sh' do
          is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/handles forcibly enabling puppet agent/)
        end

        it 'uses a computed max disable time to enable puppet in puppetagent_cron.sh' do
          expected = Regexp.escape('if [[ ${pup_status} -ne 0 && $(( ${now} - ${filedate} )) -gt 16200')
          is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/#{expected}/)
        end
      end

      context "with 'rand' randomization algorithm for cron minute" do
        let(:params) {{ :minute => 'rand' }}

        it { is_expected.to contain_cron('puppetagent').with({
          'command'   => '/usr/local/bin/puppetagent_cron.sh',
          'minute'    => [27,57],
          'hour'      => '*',
          'monthday'  => '*',
          'month'     => '*',
          'weekday'   => '*'
        })}

        it 'uses a computed max disable time to enable puppet in puppetagent_cron.sh' do
          expected = Regexp.escape('if [[ ${pup_status} -ne 0 && $(( ${now} - ${filedate} )) -gt 16200')
          is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/#{expected}/)
        end
      end

      context "with 'sha256' randomization algorithm for minute" do
        let(:params) {{ :minute => 'sha256' }}

        it { is_expected.to contain_cron('puppetagent').with({
          'command'   => '/usr/local/bin/puppetagent_cron.sh',
          'minute'    => [11,41],
          'hour'      => '*',
          'monthday'  => '*',
          'month'     => '*',
          'weekday'   => '*'
        })}

        it 'uses a computed max disable time to enable puppet in puppetagent_cron.sh' do
          expected = Regexp.escape('if [[ ${pup_status} -ne 0 && $(( ${now} - ${filedate} )) -gt 16200')
          is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/#{expected}/)
        end
      end

      context 'with alternate minute_base' do
        let(:params) {{ :minute_base => 'foo' }}
        it { is_expected.to contain_cron('puppetagent').with({
          'command'   => '/usr/local/bin/puppetagent_cron.sh',
          'minute'    => [29,59],
          'hour'      => '*',
          'monthday'  => '*',
          'month'     => '*',
          'weekday'   => '*'
        })}
      end

      context "with interval enabled" do
        let(:params) {{ :minute => 'nil' }}
        it { is_expected.to contain_cron('puppetagent').with({
          'minute'    => '*/30',
        })}

        it 'uses a computed max disable time to enable puppet in puppetagent_cron.sh' do
          expected = Regexp.escape('if [[ ${pup_status} -ne 0 && $(( ${now} - ${filedate} )) -gt 16200')
          is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/#{expected}/)
        end
      end

      context 'with specific cron parameters specified' do
        let(:params) {{ 
          :minute   => '1',
          :hour     => '2',
          :monthday => '3',
          :month    => '4',
          :weekday  => '5'
        }}

        it { is_expected.to contain_cron('puppetagent').with({
          'command'   => '/usr/local/bin/puppetagent_cron.sh',
          'minute'    => '1',
          'hour'      => '2',
          'monthday'  => '3',
          'month'     => '4',
          'weekday'   => '5'
        })}
      end

      context 'with altername maxruntime' do
        let(:params) {{ :maxruntime => 10 }}

        it 'uses maxruntime to kill processes in puppetagent_cron.sh' do
          expected = Regexp.escape('if [[ -n "${pup_status}" && $(( ${now} - ${filedate} )) -gt 600')
          is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/#{expected}/)
        end
      end

      context 'with break_puppet_lock disabled' do
        let(:params) {{ :break_puppet_lock => false }}
        it { is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/handles puppet processes which have been running longer than maxruntime/) }
        it { is_expected.to_not contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/handles forcibly enabling puppet agent/) }
      end


      context 'with max_disable_time specified' do
        let(:params) {{ :max_disable_time => 5 }}

        it 'uses max_disable_time to enable puppet in puppetagent_cron.sh' do
          expected = Regexp.escape('if [[ ${pup_status} -ne 0 && $(( ${now} - ${filedate} )) -gt 300')
          is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/#{expected}/)
        end
      end
    end
  end
end
