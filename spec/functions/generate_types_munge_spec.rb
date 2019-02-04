require 'spec_helper'

describe 'pupmod::generate_types_munge' do
  context 'legacy input' do
    context 'a simple environment path' do
      it do
        to_process = [
          '/safe/path',
          '/PUPPET_ENVIRONMENTPATH/to/be/munged'
        ]

        result = [
          '/safe/path',
          "#{Puppet[:environmentpath]}/to/be/munged"
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

  context 'new format input' do
    context 'a simple environment path' do
      it do
        to_process = {
          '/safe/path' => ['IN_CREATE','IN_CLOSE_WRITE'],
          '/PUPPET_ENVIRONMENTPATH/to/be/munged' => ['IN_MOVED_TO','IN_ONLYDIR']
        }

        result = {
          '/safe/path' => ['IN_CREATE','IN_CLOSE_WRITE'],
          "#{Puppet[:environmentpath]}/to/be/munged" => ['IN_MOVED_TO','IN_ONLYDIR']
        }

        expect(subject.execute(to_process)).to eq(result)
      end
    end

    context 'a multi-part environment path' do
      it do
        to_process = {
          '/safe/path' => ['IN_CREATE','IN_CLOSE_WRITE'],
          '/PUPPET_ENVIRONMENTPATH/to/be/munged' => ['IN_MOVED_TO','IN_ONLYDIR']
        }

        result = {
          '/safe/path' => ['IN_CREATE','IN_CLOSE_WRITE'],
          '/first/path/to/be/munged' => ['IN_MOVED_TO','IN_ONLYDIR'],
          '/second/path/to/be/munged' => ['IN_MOVED_TO','IN_ONLYDIR']
        }

        environment_paths = [
          '/first/path',
          '/second/path'
        ]

        expect( subject.execute(to_process, environment_paths)).to eq(result)
      end
    end
  end
end
