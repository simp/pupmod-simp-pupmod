#
# Return the location of the puppet ruby directory
#
Facter.add('puppet_ruby_dir') do
  setcode do
    require 'rubygems'
    puppet_ruby_dir = File.dirname(Gem.find_files('puppet.rb').first)
    if !puppet_ruby_dir.eql? '.'
      puppet_ruby_dir << '/puppet'
    else
      puppet_ruby_dir = 'unknown'
    end
    puppet_ruby_dir
  end
end
