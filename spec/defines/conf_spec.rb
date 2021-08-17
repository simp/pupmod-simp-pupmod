require 'spec_helper'

describe 'pupmod::conf' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) do
        os_facts
      end

      let(:title) do
        'test_thing'
      end

      context 'with basic settings' do
        let(:params) do
          {
            :setting => 'test',
            :value   => 20,
            :confdir => '/whatever'
          }
        end

        it do
          is_expected.to contain_ini_setting("pupmod_#{title}")
            .with_setting(params[:setting])
            .with_value(params[:value])
            .with_path("#{params[:confdir]}/puppet.conf")
            .with_section('main')
        end
      end

      context 'with a setting of "environment"' do
        let(:params) do
          {
            :setting => 'environment',
            :value   => 'foobar',
            :confdir => '/whatever'
          }
        end

        it do
          is_expected.to contain_ini_setting("pupmod_#{title}")
            .with_setting(params[:setting])
            .with_value(params[:value])
            .with_path("#{params[:confdir]}/puppet.conf")
            .with_section('agent')
        end
      end

      context 'with a section of "master"' do
        let(:params) do
          {
            :setting => 'foo',
            :section => 'master',
            :value   => 'foobar',
            :confdir => '/whatever'
          }
        end

        it do
          is_expected.to contain_ini_setting("pupmod_#{title}")
            .with_setting(params[:setting])
            .with_value(params[:value])
            .with_path("#{params[:confdir]}/puppet.conf")
            .with_section('server')
        end

        it do
          is_expected.to contain_ini_setting("pupmod_#{title}_clean")
            .with_ensure('absent')
            .with_setting(params[:setting])
            .with_path("#{params[:confdir]}/puppet.conf")
            .with_section('master')
        end
      end
    end
  end
end
