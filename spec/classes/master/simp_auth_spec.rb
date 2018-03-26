require 'spec_helper'

describe 'pupmod::master::simp_auth' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts){ os_facts }

      ['PE', 'PC1'].each do |server_distribution|
        context "server distribution '#{server_distribution}'" do
          let(:puppetserver_svc) {
            svc = 'puppetserver'

            if server_distribution == 'PE'
              svc = 'pe-puppetserver'
            end

            svc
          }

          let(:pre_condition) {
            %{ service{ #{puppetserver_svc}: } }
          }

          let(:params) {{
            :server_distribution => server_distribution
          }}


          it { is_expected.to create_class('pupmod::master::simp_auth') }
          it { is_expected.to create_puppet_authorization__rule('Allow access to the PKI cacerts from the legacy pki module from all hosts').with({
            'ensure'               => 'absent',
            'match_request_path'   => '^/puppet/v3/file_(metadata|content)/modules/pki/keydist/cacerts',
            'match_request_type'   => 'regex',
            'match_request_method' => ['get'],
            'allow'                => '*',
            'sort_order'           => 400,
          }) }
          it { is_expected.to create_puppet_authorization__rule('Allow access to the cacerts from the pki_files module from all hosts').with({
            'ensure'               => 'present',
            'match_request_path'   => '^/puppet/v3/file_(metadata|content)/modules/pki_files/keydist/cacerts',
            'match_request_type'   => 'regex',
            'match_request_method' => ['get'],
            'allow'                => '*',
            'sort_order'           => 410,
          }) }
          it { is_expected.to create_puppet_authorization__rule('Allow access to the mcollective cacerts from the legacy pki module from all hosts').with({
            'ensure'               => 'absent',
            'match_request_path'   => '^/puppet/v3/file_(metadata|content)/modules/pki/keydist/mcollective',
            'match_request_type'   => 'regex',
            'match_request_method' => ['get'],
            'allow'                => '*',
            'sort_order'           => 420,
          }) }
          it { is_expected.to create_puppet_authorization__rule('Allow access to the mcollective PKI from the pki_files module from all hosts').with({
            'ensure'               => 'present',
            'match_request_path'   => '^/puppet/v3/file_(metadata|content)/modules/pki_files/keydist/mcollective',
            'match_request_type'   => 'regex',
            'match_request_method' => ['get'],
            'allow'                => '*',
            'sort_order'           => 430,
          }) }
          it { is_expected.to create_puppet_authorization__rule('Allow access to each hosts own certs from the pki_files module').with({
            'ensure'               => 'present',
            'match_request_path'   => '^/puppet/v3/file_(metadata|content)/modules/pki_files/keydist/([^/]+)',
            'match_request_type'   => 'regex',
            'match_request_method' => ['get'],
            'allow'                => '$2',
            'sort_order'           => 440,
          }) }
          it { is_expected.to create_puppet_authorization__rule('Allow access to each hosts own kerberos keytabs from the legacy location').with({
            'ensure'               => 'absent',
            'match_request_path'   => '^/puppet/v3/file_(metadata|content)/modules/pki_files/keytabs/([^/]+)',
            'match_request_type'   => 'regex',
            'match_request_method' => ['get'],
            'allow'                => '$2',
            'sort_order'           => 450,
          }) }

          it { is_expected.to create_puppet_authorization__rule('Allow access to each hosts own kerberos keytabs from the krb5_files module').with({
            'ensure'               => 'present',
            'match_request_path'   => '^/puppet/v3/file_(metadata|content)/modules/krb5_files/keytabs/([^/]+)',
            'match_request_type'   => 'regex',
            'match_request_method' => ['get'],
            'allow'                => '$2',
            'sort_order'           => 460,
            'notify'               => "Service[#{puppetserver_svc}]"
          }) }
          it { is_expected.to create_file('/etc/puppetlabs/puppet/auth.conf').with_ensure('absent') }
        end
      end
    end
  end
end
