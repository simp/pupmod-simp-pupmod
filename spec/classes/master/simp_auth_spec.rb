require 'spec_helper'

describe 'pupmod::master::simp_auth' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) do
        os_facts
      end

      context 'with default parameters' do
        it { is_expected.to create_class('pupmod::master::simp_auth') }
        it { is_expected.to create_puppet_authorization__rule('Allow PKI cacerts files from SIMP PKI module from all hosts').with({
          'match_request_path'   => '^/puppet/v3/file_(metadata|content)/modules/pki/keydist/cacerts',
          'match_request_type'   => 'regex',
          'match_request_method' => ['get'],
          'allow'                => '*',
          'sort_order'           => 400,
        }) }
        it { is_expected.to create_puppet_authorization__rule('Allow SIMP site_files cacerts access from all hosts').with({
          'match_request_path'   => '^/puppet/v3/file_(metadata|content)/site_files/pki_files/files/keydist/cacerts',
          'match_request_type'   => 'regex',
          'match_request_method' => ['get'],
          'allow'                => '*',
          'sort_order'           => 410,
        }) }
        it { is_expected.to create_puppet_authorization__rule('Allow MCO files from SIMP PKI module access from all hosts').with({
          'match_request_path'   => '^/puppet/v3/file_(metadata|content)/modules/pki/keydist/mcollective',
          'match_request_type'   => 'regex',
          'match_request_method' => ['get'],
          'allow'                => '*',
          'sort_order'           => 420,
        }) }
        it { is_expected.to create_puppet_authorization__rule('Allow SIMP site_files PKI mcollective access from all hosts').with({
          'match_request_path'   => '^/puppet/v3/file_(metadata|content)/site_files/pki_files/files/keydist/mcollective',
          'match_request_type'   => 'regex',
          'match_request_method' => ['get'],
          'allow'                => '*',
          'sort_order'           => 430,
        }) }
        it { is_expected.to create_puppet_authorization__rule('Allow SIMP PKI keydist module access from specific host').with({
          'match_request_path'   => '^/puppet/v3/file_(metadata|content)/modules/pki/keydist/([^/]+)',
          'match_request_type'   => 'regex',
          'match_request_method' => ['get'],
          'allow'                => '$2',
          'sort_order'           => 440,
        }) }
        it { is_expected.to create_puppet_authorization__rule('Allow SIMP site_files PKI keytabs access from specific host').with({
          'match_request_path'   => '^/puppet/v3/file_(metadata|content)/site_files/pki_files/files/keytabs/([^/]+)',
          'match_request_type'   => 'regex',
          'match_request_method' => ['get'],
          'allow'                => '$2',
          'sort_order'           => 450,
        }) }
        it { is_expected.to create_puppet_authorization__rule('Allow SIMP site_files krb5 keytabs access from specific host').with({
          'match_request_path'   => '^/puppet/v3/file_(metadata|content)/site_files/krb5_files/files/keytabs/([^/]+)',
          'match_request_type'   => 'regex',
          'match_request_method' => ['get'],
          'allow'                => '$2',
          'sort_order'           => 460,
        }) }
      end

      context 'not managing one of the rules' do
        let(:params) {{ :site_files_mcollective_all => false }}
        it { is_expected.to create_puppet_authorization__rule('Allow PKI cacerts files from SIMP PKI module from all hosts') }
        it { is_expected.to create_puppet_authorization__rule('Allow SIMP site_files cacerts access from all hosts') }
        it { is_expected.to create_puppet_authorization__rule('Allow MCO files from SIMP PKI module access from all hosts') }
        it { is_expected.not_to create_puppet_authorization__rule('Allow SIMP site_files PKI mcollective access from all hosts') }
        it { is_expected.to create_puppet_authorization__rule('Allow SIMP PKI keydist module access from specific host') }
        it { is_expected.to create_puppet_authorization__rule('Allow SIMP site_files PKI keytabs access from specific host') }
        it { is_expected.to create_puppet_authorization__rule('Allow SIMP site_files krb5 keytabs access from specific host') }
      end

      context 'on PE' do
        let(:params) {{ :server_distribution => 'PE' }}
        it { is_expected.to create_puppet_authorization__rule('Allow SIMP site_files krb5 keytabs access from specific host').with({
          'match_request_path'   => '^/puppet/v3/file_(metadata|content)/site_files/krb5_files/files/keytabs/([^/]+)',
          'match_request_type'   => 'regex',
          'match_request_method' => ['get'],
          'allow'                => '$2',
          'sort_order'           => 460,
          'notify'               => 'Service[pe-puppetserver]'
        }) }
      end

    end
  end
end
