# Return an Array of Stdlib::AbsolutePath (legacy compat), or a Hash of
# AbsolutePath and String values that have the string
# PUPPET_ENVIRONMENTPATH replaced by the Puppet environment paths.
#
#
Puppet::Functions.create_function(:'pupmod::generate_types_munge') do
  require 'json'

  # This version is present for legacy purposes
  #
  # @example with a multi-part ``environmentpath`` of ``/here:/there``
  #   pupmod::generate_types_munge(['PUPPET_ENVIRONMENTPATH/foo/bar'])
  #
  #   returns: ['/here/foo/bar', '/there/foo/bar']
  #
  # @param to_process
  #   The Array of AbsolutePaths to process
  #
  # @param environment_paths
  #   The list of environment paths to use as a replacement
  #
  dispatch :generate_types_munge_legacy do
    param 'Array[Stdlib::AbsolutePath]', :to_process
    optional_param 'Array[Stdlib::AbsolutePath]', :environment_paths
    return_type 'Array[Stdlib::AbsolutePath]'
  end

  def generate_types_munge_legacy(to_process, environment_paths=nil)
    get_environmentpaths(environment_paths).map { |environment_path|
      to_process.map { |target|
        target.gsub(/\/?PUPPET_ENVIRONMENTPATH/, environment_path)
      }
    }.flatten.uniq
  end

  # @example with a multi-part ``environmentpath`` of ``/here:/there``
  #   pupmod::generate_types_munge({
  #     'PUPPET_ENVIRONMENTPATH/foo/bar => [<MASKS>]
  #   })
  #
  #   returns: { '/here/foo/bar' => [<MASKS>], '/there/foo/bar' => [<MASKS>] }
  #
  # @param to_process
  #   The Array of AbsolutePaths to process
  #
  # @param environment_paths
  #   The list of environment paths to use as a replacement
  #
  # @return [Hash[Stdlib::AbsolutePath, Array[String]]]
  dispatch :generate_types_munge do
    param 'Hash[Stdlib::AbsolutePath, Array[String]]', :to_process
    optional_param 'Array[Stdlib::AbsolutePath]', :environment_paths
    return_type 'Hash[Stdlib::AbsolutePath, Array[String]]'
  end

  def generate_types_munge(to_process, environment_paths=nil)
    result = Hash.new

    to_process.each do |target, masks|
      if target.include?('PUPPET_ENVIRONMENTPATH')
        get_environmentpaths(environment_paths).each do |environment_path|
          result[target.gsub(/\/?PUPPET_ENVIRONMENTPATH/, environment_path)] = masks
        end
      else
        result[target] = masks
      end
    end

    result
  end

  def get_environmentpaths(environment_paths = nil)
    return environment_paths if environment_paths

    internal_envpath = Facter.value(:puppet_environmentpath)

    if internal_envpath && !internal_envpath.empty?
      return internal_envpath.split(':')
    end

    return ['/etc/puppetlabs/code/environments']
  end
end

