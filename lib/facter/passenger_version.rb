#
# Return the version of passenger installed on the system.
# 
# Returns 'unknown' if the version cannot be determined.
#
Facter.add("passenger_version") do
  passenger = Facter::Core::Execution.which('passenger')
  confine { passenger }

  setcode do
    passenger_version = 'unknown'
    begin
      %x{#{passenger} --version}.to_s.split("\n").first =~ /((\d\.?)+)/
      passenger_version = $1 if not $1.to_s.empty?
    rescue Errno::ENOENT
      # No-op this because we only care that the passenger version is unknown
    end
    passenger_version
  end
end
