# Split out the 'service' for cleaner dependency ordering
#
# The service is only managed when `service_ensure` or `service_enable` is
# set. Configuration changes notify this class, so while the service is
# unmanaged they take effect at the next restart of puppetserver (or a
# reload, see `pupmod::master::base::helper_scripts`).
#
# @param service_name Name of the puppetserver service
#
# @param service_ensure
#   The `ensure` of the puppetserver service. `undef` leaves it alone.
#
# @param service_enable
#   The `enable` of the puppetserver service. `undef` leaves it alone.
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class pupmod::master::service (
  String[1]                           $service_name   = pupmod::server_distribution() ? { 'PE' => 'pe-puppetserver', default => 'puppetserver' },
  Optional[Enum['running', 'stopped']] $service_ensure = undef,
  Optional[Boolean]                   $service_enable = undef,
) {
  if (pupmod::server_distribution() != 'PE') and ($service_ensure =~ NotUndef or $service_enable =~ NotUndef) {
    service { $service_name:
      ensure     => $service_ensure,
      enable     => $service_enable,
      hasrestart => true,
      hasstatus  => true,
    }
  }
}
