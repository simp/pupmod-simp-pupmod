require 'spec_helper'

# Test pupmod::facter::conf via pupmod, because pupmod::facter::conf is private.
# To take advantage of hooks built into puppet-rspec, the class described needs
# to be the class instantiated, i.e., pupmod.
describe 'pupmod' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      let(:conf_dir) { '/etc/puppetlabs/facter' }
      let(:conf_file) { '/etc/puppetlabs/facter/facter.conf' }

      context 'with default facter_options (empty)' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('pupmod::facter::conf') }
        it { is_expected.to have_hocon_setting_resource_count(0) }
      end

      context 'with the deprecated manage_facter_conf => true and no facter_options' do
        let(:params) { { manage_facter_conf: true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('pupmod::facter::conf') }
      end

      context 'with facter_options' do
        let(:params) do
          {
            facter_options: {
              'facts' => {
                'blocklist' => ['EC2'],
                'ttls'      => [
                  { 'processor' => '30 days' },
                  { 'timezone'  => '8 hours' },
                ],
              },
              'global' => {
                'external-dir' => ['path1', 'path2'],
                'no-ruby'      => false,
                'custom-dir'   => 'absent',
              },
              'cli' => {},
            },
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('pupmod::facter::conf') }
        it { is_expected.to contain_file(conf_dir).with_ensure('directory') }
        it { is_expected.to contain_file(conf_file).with_ensure('file') }
        it {
          is_expected.to contain_hocon_setting('facts.blocklist').with(
            ensure: 'present',
            path: conf_file,
            setting: 'facts.blocklist',
            value: ['EC2'],
            type: 'array',
          )
        }
        it {
          is_expected.to contain_hocon_setting('facts.ttls').with(
            setting: 'facts.ttls',
            value: [{ 'processor' => '30 days' }, { 'timezone' => '8 hours' }],
            type: 'array',
          )
        }
        it { is_expected.to contain_hocon_setting('global.external-dir').with(value: ['path1', 'path2'], type: 'array') }
        it { is_expected.to contain_hocon_setting('global.no-ruby').with(ensure: 'present', value: false, type: nil) }
        it { is_expected.to contain_hocon_setting('global.custom-dir').with(ensure: 'absent', setting: 'global.custom-dir') }
        it 'removes an empty section' do
          is_expected.to contain_hocon_setting('cli').with(ensure: 'absent', path: conf_file, setting: 'cli')
        end
        it { is_expected.not_to contain_hocon_setting('facts') }
        it { is_expected.not_to contain_hocon_setting('global') }
      end

      context 'with facter_options and the deprecated manage_facter_conf => false' do
        let(:params) do
          {
            manage_facter_conf: false,
            facter_options: { 'facts' => { 'blocklist' => ['EC2'] } },
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_class('pupmod::facter::conf') }
      end
    end
  end
end
