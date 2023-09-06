require 'spec_helper'

describe 'pupmod::max_active_instances' do
    on_supported_os.each do |os, os_facts|
        context "on #{os}" do
            context 'with os defaults' do
                let(:facts) { os_facts }
                it { is_expected.to run }
            end

            context '4C and 8GB' do
                let(:facts) { os_facts.merge({
                    :memorysize_mb => 8192,
                    :processorcount => 4,
                    :processors => {
                        :physicalcount => 1,
                        :count => 4,
                        :models => [
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz"
                        ]
                    }
                })}

                it { is_expected.to run.and_return(2) }
                it { is_expected.to run.with_params('primary').and_return(2) }
                it { is_expected.to run.with_params('compile').and_return(3) }
            end

            context '8C and 16GB' do
                let(:facts) { os_facts.merge({
                    :memorysize_mb => 16384,
                    :processorcount => 8,
                    :processors => {
                        :physicalcount => 2,
                        :count => 8,
                        :models => [
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz"
                        ]
                    }
                })}

                it { is_expected.to run.and_return(5) }
                it { is_expected.to run.with_params('primary').and_return(2) }
                it { is_expected.to run.with_params('compile').and_return(7) }
            end

            context '16C and 32GB' do
                let(:facts) { os_facts.merge({
                    :memorysize_mb => 32768,
                    :processorcount => 16,
                    :processors => {
                        :physicalcount => 4,
                        :count => 16,
                        :models => [
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz"
                        ]
                    }
                })}

                it { is_expected.to run.and_return(11) }
                it { is_expected.to run.with_params('primary').and_return(4) }
                it { is_expected.to run.with_params('compile').and_return(15) }
            end

            # Test memory limited
            context '16C and 4GB' do
                let(:facts) { os_facts.merge({
                    :memorysize_mb => 4096,
                    :processorcount => 16,
                    :processors => {
                        :physicalcount => 4,
                        :count => 16,
                        :models => [
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz",
                            "Intel(R) Core(TM) i7-5500U CPU @ 2.40GHz"
                        ]
                    }
                })}

                it { is_expected.to run.and_return(3) }
                it { is_expected.to run.with_params('primary').and_return(3) }
                it { is_expected.to run.with_params('compile').and_return(3) }
            end
        end
    end
end
