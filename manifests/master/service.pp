# Split out the 'service' for cleaner dependency ordering
#
# @param service_name Name of the puppetserver service
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class pupmod::master::service(
  String[1] $service_name = pupmod::server_distribution() ? { 'PE' => 'pe-puppetserver', default => 'puppetserver' }
) {

  if pupmod::server_distribution() != 'PE' {
    service { $service_name:
      ensure     => 'running',
      enable     => true,
      hasrestart => true,
      hasstatus  => true,
    }
  }
}
