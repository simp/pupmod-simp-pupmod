module GenerateTypesTestUtil
  # Wait until simp_generate_types has finished processing
  def wait_for_generate_types(host, timeout=1200, interval=30)
    # Let everything spawn
    sleep(2)

    begin
      require 'timeout'

      Timeout::timeout(1200) do
        done_generating = false
        while !done_generating do
          result = on(host, 'pgrep -f simp_generate_types', :accept_all_exit_codes => true)
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
