#
require 'spec_helper'

describe 'pupmod::master::base' do
  on_supported_os.each do |os, os_facts|
    before :all do
      @extras = { :puppet_settings => {
        'master' => {
          'rest_authconfig' => '/etc/puppetlabs/puppet/authconf.conf'
      }}}
    end
    context "on #{os}" do

      let(:facts){ @extras.merge(os_facts) }

      context 'with default parameters' do
        it { is_expected.to create_class('pupmod::master::base') }
        it { is_expected.to contain_simpcat_build('autosign').with(
            {
              "quiet" => true,
              "order" => ['*.autosign'],
              "target" => "/etc/puppetlabs/puppet/autosign.conf",
            }
          )
        }
        it { is_expected.to contain_exec('puppetserver_reload').with(
            {
              "command" => "/usr/local/sbin/puppetserver_reload",
              "refreshonly" => true,
            }
          )
        }
        it { is_expected.to contain_file('/etc/puppetlabs/puppet/ssl/ca/ca_crl.pem').with(
            {
              "audit" => "content",
            }
          )
        }
        it { is_expected.to contain_file('/etc/puppetlabs/puppetserver/conf.d/autosign.conf').with(
            {
              "owner" => "root",
              "group" => "puppet",
              "mode" => "0644",
            }
          )
        }
        it { is_expected.to contain_file('/etc/puppetlabs/code/environments').with(
            {
              "ensure" => "directory",
              "owner" => "root",
              "group" => "puppet",
              "mode" => "u=rwx,g=rwx,o-rwx",
              "recurse" => true,
              "recurselimit" => 1,
            }
          )
        }
        it { is_expected.to contain_file('/usr/local/sbin/puppetserver_clear_environment_cache').with(
            {
              "ensure" => "file",
              "owner" => "root",
              "group"  => "root",
              "mode" => "0700",
            }
          )
        }
        puppetserver_clear_environment_cache = File.open("#{File.dirname(__FILE__)}/data/puppetserver_clear_environment_cache.txt", "rb").read;
        it { is_expected.to contain_file('/usr/local/sbin/puppetserver_clear_environment_cache').with_content(puppetserver_clear_environment_cache) }

        it { is_expected.to contain_file('/usr/local/sbin/puppetserver_reload').with(
            {
              "ensure" => "file",
              "owner" => "root",
              "group"  => "root",
              "mode" => "0700",
            }
          )
        }
        puppetserver_reload = File.open("#{File.dirname(__FILE__)}/data/puppetserver_reload.txt", "rb").read;
        it { is_expected.to contain_file('/usr/local/sbin/puppetserver_reload').with_content(puppetserver_reload) }

        it { is_expected.to contain_group('puppet').with(
            {
              "ensure" => "present",
              "allowdupe" => false,
              "gid" => "52",
              "tag" => "firstrun",
            }
          )
        }
        it { is_expected.to contain_package('puppetserver').with(
            {
              "ensure" => "latest",
            }
          )
        }
        it { is_expected.to contain_service('puppetserver').with(
            {
              "ensure" => "running",
              "enable" => true,
              "hasrestart" => true,
              "hasstatus" => true,
            }
          )
        }
        it { is_expected.to contain_user('puppet').with(
            {
              "ensure" => "present",
              "allowdupe" => false,
              "comment" => "Puppet User",
              "uid" => "52",
              "gid" => "puppet",
              "home" => "/opt/puppetlabs/server/data/puppetserver",
              "membership" => "inclusive",
              "shell" => "/sbin/nologin",
              "tag" => "firstrun",
            }
          )
        }
      end
    end
  end
end
