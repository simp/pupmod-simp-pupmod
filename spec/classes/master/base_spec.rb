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
        it { is_expected.to contain_exec('puppetserver_reload').with(
            {
              "command" => "/usr/local/sbin/puppetserver_reload",
              "refreshonly" => true,
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
        it {
          puppetserver_clear_environment_cache = File.open("#{File.dirname(__FILE__)}/data/puppetserver_clear_environment_cache.txt", "rb").read.gsub('foo.example.com', facts[:fqdn])
          is_expected.to contain_file('/usr/local/sbin/puppetserver_clear_environment_cache').with_content(puppetserver_clear_environment_cache)
        }

        it { is_expected.to contain_file('/usr/local/sbin/puppetserver_reload').with(
            {
              "ensure" => "file",
              "owner" => "root",
              "group"  => "root",
              "mode" => "0700",
            }
          )
        }
        it {
          puppetserver_reload = File.open("#{File.dirname(__FILE__)}/data/puppetserver_reload.txt", "rb").read.gsub('foo.example.com', facts[:fqdn])
          is_expected.to contain_file('/usr/local/sbin/puppetserver_reload').with_content(puppetserver_reload)
        }

        it { is_expected.to contain_group('puppet').with(
            {
              "ensure" => "present",
              "allowdupe" => false,
              "tag" => "firstrun",
            }
          )
        }
        it { is_expected.to contain_package('puppetserver').with(
            {
              "ensure" => "installed",
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
              "gid" => "puppet",
              "home" => "/opt/puppetlabs/server/data/puppetserver",
              "shell" => "/sbin/nologin",
              "tag" => "firstrun",
            }
          )
        }
      end

    end
  end
end
