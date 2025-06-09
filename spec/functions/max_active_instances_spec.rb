require 'spec_helper'

describe 'pupmod::max_active_instances' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      context '4C and 8GB' do
        let(:facts) do
          os_facts.merge(
            memory: {
              'system' => {
                'total_bytes' => (8192 * 1_048_576).to_i,
              },
            },
            processors: {
              physicalcount: 1,
              count: 4,
              models: [
                'Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz',
              ] * 4,
            },
          )
        end

        it { is_expected.to run.and_return(2) }
        it { is_expected.to run.with_params('primary').and_return(2) }
        it { is_expected.to run.with_params('compile').and_return(3) }
      end

      context '8C and 16GB' do
        let(:facts) do
          os_facts.merge(
            memory: {
              'system' => {
                'total_bytes' => (16_384 * 1_048_576).to_i,
              },
            },
            processors: {
              physicalcount: 2,
              count: 8,
              models: [
                'Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz',
              ] * 8,
            },
          )
        end

        it { is_expected.to run.and_return(5) }
        it { is_expected.to run.with_params('primary').and_return(2) }
        it { is_expected.to run.with_params('compile').and_return(7) }
      end

      context '16C and 32GB' do
        let(:facts) do
          os_facts.merge(
            memory: {
              'system' => {
                'total_bytes' => (32_768 * 1_048_576).to_i,
              },
            },
            processors: {
              physicalcount: 4,
              count: 16,
              models: [
                'Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz',
              ] * 16,
            },
          )
        end

        it { is_expected.to run.and_return(11) }
        it { is_expected.to run.with_params('primary').and_return(4) }
        it { is_expected.to run.with_params('compile').and_return(15) }
      end

      context '16C and 4GB' do
        let(:facts) do
          os_facts.merge(
            memory: {
              'system' => {
                'total_bytes' => (4096 * 1_048_576).to_i,
              },
            },
            processors: {
              physicalcount: 4,
              count: 16,
              models: [
                'Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz',
              ] * 16,
            },
          )
        end

        it { is_expected.to run.and_return(3) }
        it { is_expected.to run.with_params('primary').and_return(3) }
        it { is_expected.to run.with_params('compile').and_return(3) }
      end
    end
  end
end
