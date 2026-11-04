require 'spec_helper_acceptance'

# Every setting is independently enforceable: a run that sets one setting
# alone, with no profile, makes it take effect; a later run that no longer
# sets it leaves it in place; and 'absent' removes it.
describe 'independently enforced settings' do
  let(:manifest) { "class { 'pupmod': enable_puppet_master => true }" }

  def puppet_conf_runinterval(host)
    on(host, "grep -E '^\\s*runinterval\\s*=' /etc/puppetlabs/puppet/puppet.conf", accept_all_exit_codes: true).stdout.strip
  end

  def max_queued_requests(host)
    on(host, "grep -E '^\\s*max-queued-requests\\s*[:=]' /etc/puppetlabs/puppetserver/conf.d/puppetserver.conf", accept_all_exit_codes: true).stdout.strip
  end

  hosts_with_role(hosts, 'simp_master').each do |host|
    context "on #{host}" do
      it 'writes the settings when they are set alone' do
        set_hieradata_on(host, {
                           'pupmod::runinterval'                       => 1234,
                           'pupmod::master::max_queued_requests'       => 42,
                         })
        apply_manifest_on(host, manifest, catch_failures: true)

        expect(puppet_conf_runinterval(host)).to match(%r{=\s*1234\z})
        expect(on(host, 'puppet config print runinterval').stdout.strip).to eq('1234')
        expect(max_queued_requests(host)).to match(%r{[:=]\s*42\z})
      end

      it 'leaves them in place when they are no longer set' do
        set_hieradata_on(host, {})
        apply_manifest_on(host, manifest, catch_failures: true)

        expect(puppet_conf_runinterval(host)).to match(%r{=\s*1234\z})
        expect(max_queued_requests(host)).to match(%r{[:=]\s*42\z})
      end

      it "removes them when set to 'absent'" do
        set_hieradata_on(host, {
                           'pupmod::runinterval'                 => 'absent',
                           'pupmod::master::max_queued_requests' => 'absent',
                         })
        apply_manifest_on(host, manifest, catch_failures: true)

        expect(puppet_conf_runinterval(host)).to be_empty
        expect(max_queued_requests(host)).to be_empty
      end

      it 'is idempotent' do
        apply_manifest_on(host, manifest, catch_changes: true)
      end
    end
  end
end
