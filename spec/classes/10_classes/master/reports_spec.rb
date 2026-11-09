require 'spec_helper'

# pupmod::master::reports is private, so it is exercised through pupmod::master
describe 'pupmod::master' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.not_to contain_systemd__tmpfile('purge_puppetserver_reports.conf') }
        it { is_expected.not_to contain_file('/etc/cron.daily/puppet_client_report_purge') }
      end

      context 'with purge => true' do
        let(:hieradata) { 'master_reports_purge_true' }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file('/etc/cron.daily/puppet_client_report_purge').with_ensure('absent') }
        it {
          is_expected.to contain_systemd__tmpfile('purge_puppetserver_reports.conf')
            .with_ensure('present')
            .with_content('e /opt/puppetlabs/server/data/puppetserver/reports - - - 7d')
        }
      end

      context 'with purge => false' do
        let(:hieradata) { 'master_reports_purge_false' }

        it { is_expected.to contain_systemd__tmpfile('purge_puppetserver_reports.conf').with_ensure('absent') }
      end
    end
  end
end
