#
require 'spec_helper'

describe 'pupmod::agent::cron' do

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do

      context 'with facts set to defaults' do
        let(:facts) do 
          custom = os_facts.dup
          custom[:networking][:ip] = '10.0.2.15'
          custom[:puppet_service_enabled] = false
          custom[:puppet_service_started] = false

          custom
        end

        context 'with default params' do
          it { is_expected.to create_class('pupmod::agent::cron') }
          it { is_expected.to contain_file('/usr/local/bin/careful_puppet_service_shutdown.sh') }
          it { is_expected.to_not contain_exec('careful_puppet_service_shutdown') }
          it { is_expected.to contain_cron('puppetd').with_ensure('absent') }
          it { is_expected.to contain_cron('puppetagent').with_ensure('absent') }
          it {
            is_expected.to contain_systemd__timer('puppet_agent.timer')
              .with_timer_content(/OnCalendar=\*-\* \*:27,57/)
              .with_service_content(%r{ExecStart=/usr/local/bin/puppetagent_cron.sh})
              .with_service_content(/SuccessExitStatus=2/)
              .that_requires('File[/usr/local/bin/puppetagent_cron.sh]')
          }

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

          it 'stops the puppet client service in puppetagent_cron.sh' do
            expected = Regexp.escape('puppet resource service puppet enable=false ensure=false')
            is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/#{expected}/)
          end

        end

        context "with 'rand' randomization algorithm for cron minute" do
          let(:params) {{ :minute => 'rand' }}

          it {
            is_expected.to contain_systemd__timer('puppet_agent.timer')
              .with_timer_content(/OnCalendar=\*-\* \*:27,57/)
              .with_service_content(%r{ExecStart=/usr/local/bin/puppetagent_cron.sh})
              .with_service_content(/SuccessExitStatus=2/)
              .that_requires('File[/usr/local/bin/puppetagent_cron.sh]')
          }

          it 'uses a computed max disable time to enable puppet in puppetagent_cron.sh' do
            expected = Regexp.escape('if [[ ${pup_status} -ne 0 && $(( ${now} - ${filedate} )) -gt 16200')
            is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/#{expected}/)
          end
        end

        context "with 'sha256' randomization algorithm for minute" do
          let(:params) {{ :minute => 'sha256' }}

          it {
            is_expected.to contain_systemd__timer('puppet_agent.timer')
              .with_timer_content(/OnCalendar=\*-\* \*:10,40/)
              .with_service_content(%r{ExecStart=/usr/local/bin/puppetagent_cron.sh})
              .with_service_content(/SuccessExitStatus=2/)
              .that_requires('File[/usr/local/bin/puppetagent_cron.sh]')
          }

          it 'uses a computed max disable time to enable puppet in puppetagent_cron.sh' do
            expected = Regexp.escape('if [[ ${pup_status} -ne 0 && $(( ${now} - ${filedate} )) -gt 16200')
            is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/#{expected}/)
          end
        end

        context 'with alternate minute_base' do
          let(:params) {{ :minute_base => 'foo' }}

          it {
            is_expected.to contain_systemd__timer('puppet_agent.timer')
              .with_timer_content(/OnCalendar=\*-\* \*:29,59/)
              .with_service_content(%r{ExecStart=/usr/local/bin/puppetagent_cron.sh})
              .with_service_content(/SuccessExitStatus=2/)
              .that_requires('File[/usr/local/bin/puppetagent_cron.sh]')
          }

        end

        context "with interval enabled" do
          let(:params) {{ :minute => 'nil' }}

          it {
            is_expected.to contain_systemd__timer('puppet_agent.timer')
              .with_timer_content(%r{OnCalendar=\*-\* \*:\*/30})
              .with_service_content(%r{ExecStart=/usr/local/bin/puppetagent_cron.sh})
              .with_service_content(/SuccessExitStatus=2/)
              .that_requires('File[/usr/local/bin/puppetagent_cron.sh]')
          }


          it 'uses a computed max disable time to enable puppet in puppetagent_cron.sh' do
            expected = Regexp.escape('if [[ ${pup_status} -ne 0 && $(( ${now} - ${filedate} )) -gt 16200')
            is_expected.to contain_file('/usr/local/bin/puppetagent_cron.sh').with_content(/#{expected}/)
          end
        end

        context 'with specific cron parameters specified' do
          let(:params) {{
            :minute   => 1,
            :hour     => 2,
            :monthday => 3,
            :month    => 4,
            :weekday  => 5
          }}

          it {
            is_expected.to contain_systemd__timer('puppet_agent.timer')
              .with_timer_content(/OnCalendar=Fri 4-3 2:1/)
              .with_service_content(%r{ExecStart=/usr/local/bin/puppetagent_cron.sh})
              .with_service_content(/SuccessExitStatus=2/)
              .that_requires('File[/usr/local/bin/puppetagent_cron.sh]')
          }

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

      context 'with puppet service enabled' do
                let(:facts) do
          custom = os_facts.dup
          custom[:networking][:ip] = '10.0.2.15'
          custom[:puppet_service_enabled] = true
          custom[:puppet_service_started] = true

          custom
        end

        it 'should exec script to disable puppet service' do
          is_expected.to contain_exec('careful_puppet_service_shutdown')
        end
      end

    end
  end
end
