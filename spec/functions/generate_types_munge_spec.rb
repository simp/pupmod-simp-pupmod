require 'spec_helper'

describe 'pupmod::generate_types_munge' do
  context 'a simple environment path' do
    it do
      to_process = [
        '/safe/path',
        '/PUPPET_ENVIRONMENTPATH/to/be/munged'
      ]

      result = [
        '/safe/path',
        '/etc/puppetlabs/code/environments/to/be/munged'
      ]

      expect(subject.execute(to_process)).to eq(result)
    end
  end

  context 'a multi-part environment path' do
    it do
      to_process = [
        '/safe/path',
        '/PUPPET_ENVIRONMENTPATH/to/be/munged'
      ]

      environment_paths = [
        '/first/path',
        '/second/path'
      ]

      result = [
        '/safe/path',
        '/first/path/to/be/munged',
        '/second/path/to/be/munged'
      ]

      expect( subject.execute(to_process, environment_paths)).to eq(result)
    end
  end
end
