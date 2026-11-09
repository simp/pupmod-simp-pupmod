require 'spec_helper'

SIMP_AUTH_RULES = {
  pki_mcollective_all: [
    'Allow access to the mcollective PKI from the pki_files module from all hosts',
    '^/puppet/v3/file_(metadata|content)/modules/pki_files/keydist/mcollective', '*', 430
  ],
  pki_cacerts_all: [
    'Allow access to the cacerts from the pki_files module from all hosts',
    '^/puppet/v3/file_(metadata|content)/modules/pki_files/keydist/cacerts', '*', 410
  ],
  keydist_from_host: [
    'Allow access to each hosts own certs from the pki_files module',
    '^/puppet/v3/file_(metadata|content)/modules/pki_files/keydist/([^/]+)', '$2', 440
  ],
  krb5_keytabs_from_host: [
    'Allow access to each hosts own kerberos keytabs from the krb5_files module',
    '^/puppet/v3/file_(metadata|content)/modules/krb5_files/keytabs/([^/]+)', '$2', 460
  ],
}.freeze

describe 'pupmod::master::simp_auth' do
  on_supported_os.to_a.values_at(0, -1).uniq.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to have_puppet_authorization__rule_resource_count(0) }
        it { is_expected.not_to contain_puppet_authorization('/etc/puppetlabs/puppetserver/conf.d/auth.conf') }
        it { is_expected.not_to contain_file('/etc/puppetlabs/puppet/auth.conf') }
      end

      SIMP_AUTH_RULES.each do |param, (rule, path, allow, order)|
        context "with #{param} => true" do
          let(:params) { { param => true } }

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_puppet_authorization__rule(rule).with(
              ensure: 'present',
              match_request_path: path,
              match_request_type: 'regex',
              match_request_method: ['get'],
              allow: allow,
              sort_order: order,
              path: '/etc/puppetlabs/puppetserver/conf.d/auth.conf',
            ).that_notifies('Class[pupmod::master::service]').that_requires('Class[pupmod::master::install]')
          }
          # Declaring it would reset allow-header-cert-info and the file's mode
          it { is_expected.not_to contain_puppet_authorization('/etc/puppetlabs/puppetserver/conf.d/auth.conf') }
          it { is_expected.to have_puppet_authorization__rule_resource_count(1) }
        end

        context "with #{param} => false" do
          let(:params) { { param => false } }

          it { is_expected.to contain_puppet_authorization__rule(rule).with_ensure('absent') }
        end
      end

      context 'with a custom rule and deny' do
        let(:params) { { pki_cacerts_all: true, pki_cacerts_all_allow: 'ca.example.com', pki_cacerts_all_deny: 'bad.example.com' } }

        it {
          is_expected.to contain_puppet_authorization__rule(SIMP_AUTH_RULES[:pki_cacerts_all][0])
            .with(allow: 'ca.example.com', deny: 'bad.example.com')
        }
      end

      context 'with remove_legacy_auth_conf => true' do
        let(:params) { { remove_legacy_auth_conf: true } }

        it {
          is_expected.to contain_file('/etc/puppetlabs/puppet/auth.conf')
            .with(ensure: 'absent', backup: true)
            .that_notifies('Class[pupmod::master::service]')
        }
      end
    end
  end
end
