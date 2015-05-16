# _Description_
#
#
# Return the Passenger root directory.
#
Facter.add("passenger_root") do
  passenger = Facter::Core::Execution.which('passenger')
  confine { passenger }

  setcode do
    passenger_config = Facter::Core::Execution.which('passenger-config')
    rpm = Facter::Core::Execution.which('rpm')

    # If the executable is here, great....
    if File.executable?(passenger_config) then
      %x{#{passenger_config} --root}.chomp
    # If not, try the RPM
    elsif File.executable?(rpm) and file_list = %x{#{rpm} -ql rubygem-passenger} and
      $?.success?
    then
      file_list = file_list.split("\n")
      # Just pick one of these and grab the path. This seems to be the safest
      # value overall.
      file_list.index{|x|
        x =~ /^(.*)\/lib\/phusion_passenger/
      }

      $1
    # Ok, that didn't work....just guess....
    elsif Facter.value(:osfamily) == "RedHat" and
      File.directory?(Dir.glob('/usr/share/rubygems/gems/passenger-*').first.to_s)
    then
      Dir.glob('/usr/share/rubygems/gems/passenger-*').sort.last
    else
      "could not determine passenger root"
    end
  end
end
