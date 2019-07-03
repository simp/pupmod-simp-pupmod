# Split out the 'service' for cleaner dependency ordering
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class pupmod::master::service(
  String[1] $service_name = simplib::lookup('simp_options::puppet::server_distribution', { 'default_value' => 'PC1' }) ? { 'PE' => 'pe-puppetserver', default => 'puppetserver'}
) {
  service { $service_name:
    ensure     => 'running',
    enable     => true,
    hasrestart => true,
    hasstatus  => true
  }
}
