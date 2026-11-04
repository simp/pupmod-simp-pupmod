module GenerateTypesTestUtil
  # Wait until simp_generate_types has finished processing
  def wait_for_generate_types(host, _timeout = 1200, interval = 30)
    # Let everything spawn
    sleep(2)

    begin
      require 'timeout'

      Timeout.timeout(1200) do
        done_generating = false
        until done_generating
          result = on(host, 'pgrep -f simp_generate_types', accept_all_exit_codes: true)
          if result.exit_code != 0
            done_generating = true
          else
            puts "Waiting #{interval} seconds"
            sleep(interval)
          end
        end
      end
    rescue => e
      raise(e)
    end
  end
end

# Helpers for enforcing the `simp:defaults` compliance profile on a SUT
module PupmodTestUtil
  # Hieradata for a SIMP site: the simp_options keys `simp config` sets, which
  # pupmod follows instead of the profile
  def simp_site_hieradata(host)
    fqdn = fact_on(host, 'networking.fqdn')

    {
      'simp_options::puppet::server'  => fqdn,
      'simp_options::puppet::ca'      => fqdn,
      'simp_options::puppet::ca_port' => 8141,
      'simp_options::trusted_nets'    => ['ALL'],
    }
  end

  # Adds the Compliance Engine layer to the environment's hiera.yaml, last so
  # it has the lowest priority, as it does at a real site
  def enable_compliance_engine_on(host)
    config = YAML.safe_load(get_hiera_config_on(host))
    return if config['hierarchy'].any? { |level| level['lookup_key'] == 'compliance_engine::enforcement' }

    config['hierarchy'] << {
      'name'       => 'Compliance Engine',
      'lookup_key' => 'compliance_engine::enforcement',
    }
    set_hiera_config_on(host, config)
  end

  # Replaces the hieradata with `simp:defaults` enforced on a SIMP site, plus
  # `extra`
  def set_simp_defaults_hieradata_on(host, extra = {})
    enable_compliance_engine_on(host)
    set_hieradata_on(host, { 'compliance_engine::enforcement' => ['simp:defaults'] }.merge(simp_site_hieradata(host)).merge(extra))
  end
end
