# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What this module does

`simp-pupmod` is the SIMP Puppet module that **manages Puppet itself** — both the
puppet agent and the puppetserver ("master") on Enterprise Linux. It writes
`puppet.conf` settings, installs the agent/server packages, manages the
puppetserver JVM sysconfig and HOCON config files, the CA config, autosign and
fileserver entries, report purging, a systemd-timer-based agent run schedule, and
(optionally) Facter config, firewall openings, and auditd rules. It is
distribution-aware: it detects and adapts to FOSS/OpenVox puppetserver vs. Puppet
Enterprise (PE).

Since 13.0.0 a bare `include pupmod` (or `include pupmod::master`) installs the
package and **declares nothing else**. Every other behavior is opt-in through a
parameter, and every setting is three-state: `undef` (default) leaves it alone,
a value writes it, `'absent'` removes it. Configuration files are edited in
place one setting at a time (`ini_setting`, `ini_subsetting`, `hocon_setting`,
`augeas`, `file_line`); no package-shipped file is rendered whole. The shipped
`simp:defaults` compliance profile (`SIMP/compliance_profiles/`) restores the
12.x behavior when `compliance_engine::enforcement: [simp:defaults]` is set.

The top-level `pupmod` class (`manifests/init.pp`) is the agent-side
entry point and a "stub" that hooks in the other classes; setting
`pupmod::enable_puppet_master: true` pulls in the server side via
`pupmod::master` (`init.pp`). Nearly every class honours a `$mock`
parameter that short-circuits the body so the catalog can be compiled/inspected
without declaring real resources (`init.pp`, `master.pp`,
`sysconfig.pp`).

### Business logic

The module has **many** classes/defines. Only five classes call
`assert_private()`; everything else is part of the public API even when it is
"internal" in spirit. Verified `assert_private()` calls: `pupmod::agent::install`
(`agent/install.pp`), `pupmod::facter::conf` (`facter/conf.pp`),
`pupmod::master::install` (`master/install.pp`), `pupmod::master::reports`
(`master/reports.pp`), `pupmod::pass_two` (`pass_two.pp`).

Agent side:

- **`pupmod` (`manifests/init.pp`)** — Public entry class. Guarded by
  `unless $mock` (`init.pp`); first runs `simplib::assert_metadata($module_name)`.
  Orchestration: optionally `include 'rngd'` if `$rngd`, or the deprecated
  `include 'haveged'` if `$haveged` (optional dependency); always
  `include pupmod::agent::install`; `include 'pupmod::master'` when
  `$enable_puppet_master`. `$daemonize` is `Optional[Boolean]`: `true` runs
  `service { 'puppet' }` and removes the timer, `false` stops it and includes
  `pupmod::agent::cron`, `undef` manages neither. `[main]` settings (splay,
  syslogfacility, srv_domain, certname, classfile, runinterval,
  digest_algorithm, splaylimit, plus the `main_settings` Hash) are written via
  `pupmod::conf` only when set. Also opt-in: `$puppet_extra_opts`
  (`/etc/sysconfig/puppet`, `file_line`), `$puppetagent_manage_all_files`
  (SELinux boolean exec + its package on EL10), `$purge_logs` (systemd
  tmpfile), `$puppet_group` (group + ownership/mode of confdir and
  puppet.conf, applied in `pass_two`), `$facter_options` (Facter config).
  The path parameters (`confdir`, `vardir`, ...) are operational module data,
  not written to `puppet.conf`. See the pass-two note below.
- **`pupmod::agent::install` (`manifests/agent/install.pp`)** — Private
  (`assert_private()`, `install.pp`). Installs `$package_name`
  (default `$pupmod::agent_package` → `openvox-agent`, `init.pp`).
- **`pupmod::agent::cron` (`manifests/agent/cron.pp`)** — Public. Despite
  the name it configures a **systemd timer** (`systemd::timer`, `cron.pp`), not
  cron; it removes legacy `puppetd`/`puppetagent` cron jobs (`cron.pp`).
  `$minute` supports randomization algorithms `ip_mod`/`rand`/`sha256` via
  `simplib::rand_cron` (`cron.pp`), converted to a systemd calendar with
  `simplib::cron::to_systemd` (`cron.pp`). Disables the `puppet` service in
  the background when cron is enabled (`cron.pp`, works around PUP-1320).
- **`pupmod::facter::conf` (`manifests/facter/conf.pp`)** — Private
  (`assert_private()`, `facter/conf.pp`). Writes `facter.conf` HOCON settings
  from the `$facter_options` hash (`facter/conf.pp`). Only included when
  `pupmod::manage_facter_conf` is true (`init.pp`).
- **`pupmod::conf` (define, `manifests/conf.pp`)** — Public define. Thin
  wrapper over `ini_setting` on `puppet.conf`; the module's primary way of setting
  puppet.conf keys. `master` section is auto-rewritten to `server`
  (`conf.pp`) and a matching stale `master`-section entry is removed
  (`conf.pp`); `environment` is forced into the `agent` section
  (`conf.pp`, SIMP-6820).
- **`pupmod::pass_two` (define, `manifests/pass_two.pp`)** — Private
  (`assert_private()`, `pass_two.pp`). Declared virtually and realized
  immediately in `pupmod` (`@pupmod::pass_two { 'main' }` then
  `Pupmod::Pass_two <| |>`, `init.pp`) to defer its logic to the catalog
  compiler's **second pass** so `defined(Class[...])` PE-detection checks are
  reliable (see the long comment `init.pp`). Sets `server`/`server_list`,
  `ca_server`, ports, and report settings for FOSS/OpenVox when set
  (`pass_two.pp`); manages the `puppet_group` group and confdir/puppet.conf
  ownership when set; builds PE user/service/firewall data from
  `$pe_classlist` (empty by default, so PE integration is off); and
  **`fail()`s if both `puppet_enterprise::profile::master` and
  `pupmod::master` are classified** (`pass_two.pp`).

Server side (`pupmod::master*`):

- **`pupmod::master` (`manifests/master.pp`)** — Public. `inherits pupmod`
  (`master.pp`), `unless $mock` (`master.pp`) it includes and orders the
  seven master subclasses, manages the server directories' ownership when
  `pupmod::puppet_group` is set, and writes `[server]`/`[main]`
  `pupmod::conf` settings only when set (`keylength` is its own parameter;
  the profile picks 2048/4096 by `fips_enabled`). A **CVE-2020-7942
  warning** fires when `$strict_hostname_checking` is `false`; optional
  `auditd` rule and `iptables` openings (the main port, from `masterport`, else
  `webserver.conf`, else 8140; the CA port from `ca_port`, else the `ca` server in `webserver.conf`) when `$firewall`;
  `autosign_entries`/deprecated `autosign_hosts` realized via
  `ensure_resource`.
- **`pupmod::master::config` (`manifests/master/config.pp`)** — Private
  (`assert_private()`). Edits the puppetserver files in place:
  `hocon_setting` for `puppetserver.conf`, `ca.conf`, `webserver.conf`,
  `web-routes.conf`, `product.conf`; `file_line` for `services.d/ca.cfg`;
  `augeas` (Xml lens) for `logback.xml`. **`webserver.conf` layout:** when
  `ca_port` differs from the main port it converts the file to named servers
  (`base` + `ca`), moving the existing single-server keys under `base`; the
  `puppetserver_webserver` fact reports the current layout so settings are
  written where puppetserver reads them.
- **`pupmod::master::install` (`manifests/master/install.pp`)** — Private
  (`assert_private()`, `master/install.pp`). Installs the server package
  (`openvox-server`, or `pe-puppetserver` on PE). For OpenVox it either installs a
  directly-supplied RPM (`pupmod::openvox_rpm_path`) or the OpenVox release RPM +
  server package from `pupmod::openvox_base_url` (`master/install.pp`).
- **`pupmod::master::service` (`manifests/master/service.pp`)** — Public.
  Manages `service { 'puppetserver' }` on non-PE only when `service_ensure`
  or `service_enable` is set (`master/service.pp`). Most config resources
  `notify` this class, which is a no-op while the service is unmanaged.
- **`pupmod::master::base` (`manifests/master/base.pp`)** — Public. With
  `helper_scripts: true`: the `puppetserver_reload` /
  `puppetserver_clear_environment_cache` scripts and a refresh-only reload
  exec (only while puppetserver is active). With `pupmod::puppet_group`: the
  environments dir and the `puppet` user.
- **`pupmod::master::sysconfig` (`manifests/master/sysconfig.pp`)** —
  Public. `inherits pupmod`, `unless $mock`. Edits `/etc/sysconfig/puppetserver`
  with `ini_setting` per variable and `ini_subsetting` per JVM option in
  `JAVA_ARGS`/`JAVA_ARGS_CLI` (FOSS), or PE ini subsettings; `'auto'`
  computes the JVM heap (`pupmod::java_max_memory`) and code cache; `-Xms`
  follows `-Xmx` when unset; selects the JRuby jar from the
  `puppetserver_jruby` fact.
- **`pupmod::master::reports` (`manifests/master/reports.pp`)** — Private
  (`assert_private()`, `master/reports.pp`). `inherits pupmod::master`. Purges
  old reports via a `systemd::tmpfile` when `$purge` is set (`reports.pp`);
  `$port`/`$purge_verbose` are deprecated no-ops.
- **`pupmod::master::generate_types` (`manifests/master/generate_types.pp`)** —
  Public. With `enable: true`, runs `puppet generate types` via systemd
  path/service units triggered on environment/app changes
  (`generate_types.pp`); `false` removes the units; `undef` does nothing.
  **incron support is removed** and emits a deprecation `notify` if triggers
  are disabled, plus a `tidy` of legacy `/etc/incron.d` when `enable` is set.
- **`pupmod::master::simp_auth` (`manifests/master/simp_auth.pp`)** —
  Public. Adds or removes SIMP-specific `puppet_authorization::rule` entries
  (pki_files cacerts/keydist, krb5 keytabs) in the puppetserver `auth.conf`,
  each only when its Boolean is set (`simp_auth.pp`), and removes the stray
  agent-dropped `/etc/puppetlabs/puppet/auth.conf` when
  `remove_legacy_auth_conf` is true.
- **`pupmod::master::autosign` (define, `manifests/master/autosign.pp`)** —
  Public. Adds or removes (`ensure`) one `file_line` in `autosign.conf`;
  `fail()`s if `$name` is not a valid autosign pattern when no `$entry` is
  given (`autosign.pp`).
- **`pupmod::master::fileserver_entry` (define,
  `manifests/master/fileserver_entry.pp`)** — Public. Sets the `path` of a
  `fileserver.conf` `[segment]` via `ini_setting` (`fileserver_entry.pp`).

Puppet-language functions (`functions/`, all `pupmod::*`): `server_distribution`
(FOSS/OpenVox/PE detection, `functions/server_distribution.pp`), `server_version`,
`java_max_memory`, `max_active_instances`, `reserved_code_cache`. Custom Ruby facts
(`lib/facter/`): `puppet_ruby_dir`, `puppetserver_jruby`, `puppetserver_webserver`,
`puppet_service_enabled`, `puppet_service_started`, `simp_pupmod_serverversion`.

### Gotchas / non-obvious details

- **The "pass two" trick is load-bearing.** `pupmod::pass_two` is declared as a
  virtual resource and realized immediately (`init.pp`) purely to push its
  logic into the catalog compiler's second pass, so its `defined(Class[...])`
  PE-detection is reliable. Don't "simplify" it into inline code — read the comment
  at `init.pp`.
- **`pupmod::master` on a PE master is a hard failure.** If both
  `puppet_enterprise::profile::master` and `pupmod::master` are classified,
  `pupmod::pass_two` calls `fail()` (`pass_two.pp`).
- **`pupmod::agent::cron` is a systemd timer, not cron.** The name is retained for
  backward compatibility (`agent/cron.pp`); it declares `systemd::timer`
  (`cron.pp`) and removes the old cron jobs.
- **The CA keylength is `pupmod::master::keylength`.** The `simp:defaults`
  profile sets 2048 when the `fips_enabled` fact is true, 4096 otherwise.
  `pupmod::fips` is unused since 13.0.0.
- **Bare include must stay package-only.** `init_spec.rb`/`master_spec.rb`
  assert it; `spec/classes/simp_defaults_profile_spec.rb` asserts the profile
  restores the 12.x catalog. New behavior needs a parameter defaulting to
  `undef` (or a safe `false`) and, if it was automatic before, a check in
  `SIMP/compliance_profiles/checks.yaml`.
- **`hocon_setting` writes a one-element Array as a scalar** unless
  `type => 'array'` is passed; `config.pp` and `facter/conf.pp` set it.
- **`$mock` compiles a no-op catalog.** `pupmod`, `pupmod::master`, and
  `pupmod::master::sysconfig` wrap their bodies in `unless $mock`
  (`init.pp`, `master.pp`, `sysconfig.pp`) — used for testing/inspection.
- **`master` → `server` section rewriting is pervasive.** `pupmod::conf` rewrites
  the `master` section to `server` and cleans the stale entry (`conf.pp`);
  many manifests use `pick($facts.dig('puppet_settings','server',...),
  $facts.dig('puppet_settings','master',...))` to bridge the Puppet 6.19 rename
  (e.g. `base.pp`, `master.pp`, `pass_two.pp`).
- **CVE-2020-7942 is deliberately guarded.** Turning off
  `strict_hostname_checking` (setting it to `false`) emits a warning `notify`
  (`master.pp`); `simp:defaults` sets it to `true`.
- **`simp/simp_options` is NOT a declared dependency** in `metadata.json`, yet the
  manifests consume the `simp_options::*` seam via `simplib::lookup` (provided by
  `simp/simplib`). `simp_options` appears only as a fixture (`.fixtures.yml`).
  The `default_value` in each `simplib::lookup` call is what makes the classes
  compile without it.
- **Several declared dependencies are used conditionally.** `simp/iptables`
  (`master.pp`, `pass_two.pp`), `simp/rngd` (`init.pp`), and
  `auditd` (`master.pp`, not a declared dep — pulled in only via `$auditd`) are
  `include`d only inside feature branches. `simp/pki` is a declared dependency but
  no `pki::` call appears in `manifests/` (retained as SIMP baseline / referenced by
  the `simp_auth` pki_files rules by path).
- **`data/os/*.yaml` files exist for AlmaLinux/CentOS/OracleLinux/RedHat/Rocky but
  only up to major 8/9.** The OS-name files describe the newest release (EL10:
  the sebool package is needed); the `-8`/`-9` files override that. Module
  data holds only what the module needs to work (paths, package names); the
  old cipher list and PE class map now live in the profile.

## The `simp_options` / `simplib::lookup` seam

The SIMP feature-toggle seam. All calls are in `manifests/init.pp` and
`manifests/master.pp`:

| File | Key | `default_value` |
|------|-----|-----------------|
| `init.pp` | `simp_options::puppet::ca` | `undef` |
| `init.pp` | `simp_options::puppet::ca_port` | `undef` |
| `init.pp` | `simp_options::puppet::server` | `undef` |
| `init.pp` | `simp_options::haveged` | `false` |
| `init.pp` | `simp_options::firewall` | `false` |
| `init.pp` | `simp_options::package_ensure` | `'installed'` |
| `master.pp` | `simp_options::auditd` | `false` |
| `master.pp` | `simp_options::puppet::ca_port` | `undef` |
| `master.pp` | `simp_options::trusted_nets` | `['127.0.0.1','::1']` |
| `master.pp` | `simp_options::firewall` | `false` |
| `master.pp` | `simp_options::syslog` | `undef` |
| `master.pp` | `simp_options::package_ensure` | `'installed'` |

Keep routing SIMP feature toggles through `simplib::lookup('simp_options::*', {
'default_value' => ... })` with an explicit default rather than assuming
`simp_options` is included. The default must be inert (`undef`, or `false` for
a feature toggle) so a bare include stays package-only. Never add a
`simp:defaults` check for these parameters: it would override the site's
`simp_options` value.

## Dependencies

Module dependencies (from `metadata.json`):

- `puppet/systemd` `>= 4.0.2 < 10.0.0` (provides `systemd::timer`,
  `systemd::tmpfile`, `systemd::unit_file`)
- `puppetlabs/stdlib` `>= 9.2.0 < 11.0.0` (`pick`, `member`, `dirname`,
  `deprecation(..., false)`, etc.)
- `puppetlabs/inifile` `>= 2.5.0 < 7.0.0` (`ini_setting`/`ini_subsetting` for
  `puppet.conf`)
- `puppetlabs/puppet_authorization` `>= 0.2.0 < 2.0.0`
  (`puppet_authorization` / `puppet_authorization::rule` for `auth.conf`)
- `puppetlabs/hocon` `>= 0.9.3 < 3.0.0` (`hocon_setting` for puppetserver/Facter
  HOCON files)
- `simp/iptables` `>= 6.5.3 < 9.0.0` (`iptables::listen::tcp_stateful`, firewall
  branch only)
- `simp/simplib` `>= 4.9.0 < 6.0.0` (`simplib::lookup`, `simplib::assert_metadata`,
  `simplib::rand_cron`, `simplib::cron::to_systemd`, `simplib::in_bolt`, and SIMP
  types)
- `simp/pki` `>= 6.2.0 < 8.0.0` (SIMP baseline; no `pki::` call in `manifests/`)
- `simp/rngd` `>= 0.2.0 < 1.0.0` (entropy daemon, included only when `$rngd`)

`simp.optional_dependencies` lists `simp/haveged` `>= 0.4.5 < 1.0.0`, used
only by the deprecated `$haveged` (checked with
`simplib::assert_optional_dependency`).
`augeas` (for `logback.xml`) comes from the `augeas_core` module vendored in
the OpenVox agent. `compliance_engine` is a spec fixture only, not a
dependency. `auditd`
(used at `master.pp`) and `puppet_enterprise` (detected via `defined()`) are
**not** declared dependencies; both appear only as fixtures (`.fixtures.yml`, with
`puppet_enterprise` mocked via `pupmod-mock-puppet_enterprise`).

Runtime requirement (from `metadata.json` `requirements`): `openvox >= 8.0.0 < 9.0.0`.

Supported OS matrix (from `metadata.json`): CentOS 9/10; RedHat 8/9/10;
OracleLinux 8/9/10; Rocky 8/9/10; AlmaLinux 8/9/10.

## Repository layout

- `manifests/init.pp` — the `pupmod` agent-side entry class.
- `manifests/master.pp` — the `pupmod::master` server orchestration class.
- `manifests/pass_two.pp` — the `pupmod::pass_two` private second-pass define.
- `manifests/conf.pp` — the `pupmod::conf` define (writes `puppet.conf`).
- `manifests/agent/` — `install.pp`, `cron.pp`.
- `manifests/facter/conf.pp` — Facter config (`pupmod::facter::conf`).
- `manifests/master/` — `install.pp`, `service.pp`, `base.pp`, `sysconfig.pp`,
  `reports.pp`, `generate_types.pp`, `simp_auth.pp`, `autosign.pp`,
  `fileserver_entry.pp`.
- `manifests/master/config.pp` — in-place puppetserver file edits (private).
- `SIMP/compliance_profiles/` — the `simp:defaults` profile and its checks.
- `functions/` — Puppet-language functions: `server_distribution.pp`,
  `server_version.pp`, `java_max_memory.pp`, `max_active_instances.pp`,
  `reserved_code_cache.pp`.
- `types/` — custom data types: `Pupmod::CaTTL`, `Pupmod::EntryOptions`, `Pupmod::LogLevel`,
  `Pupmod::Memory`, `Pupmod::ProfilingMode`, `Pupmod::Master::SSLCiphersuites`,
  `Pupmod::Master::SSLProtocols`.
- `lib/facter/` — custom Ruby facts: `puppet_ruby_dir`, `puppetserver_jruby`,
  `puppetserver_webserver`, `puppet_service_enabled`, `puppet_service_started`, `simp_pupmod_serverversion`.
- `templates/` — EPP templates for SIMP-owned files only: `os-settings.conf`,
  systemd units, the agent-cron/careful-shutdown and helper scripts, and
  auditd rules.
- `data/` + `hiera.yaml` — module data (v5 hierarchy: OS name+major → OS name →
  kernel → `common.yaml`). `common.yaml` holds `lookup_options` and the
  puppet/puppetserver path defaults. Per-OS files exist only up to major 8/9.
- `metadata.json` — deps, OS matrix, OpenVox requirement.
- `REFERENCE.md` — generated Puppet Strings reference.
- `spec/classes/`, `spec/defines/`, `spec/functions/`, `spec/unit/facter/` —
  rspec-puppet + Ruby fact unit tests; `spec/acceptance/suites/default/` — beaker
  acceptance suite with nodesets under `spec/acceptance/nodesets/`.
- **Acceptance runs in CI:** `.github/workflows/pr_tests.yml` has an `acceptance`
  job (matrix `almalinux9`, `almalinux10`) whose final step runs
  `bundle exec rake beaker:suites[default,<node>]` under
  `BEAKER_HYPERVISOR=vagrant_libvirt`.

## Common commands

```sh
# Install dependencies
bundle install

# Run all unit tests
bundle exec rake spec

# Run unit tests in parallel (as CI does)
bundle exec rake parallel_spec

# Run a single spec
bundle exec rspec spec/classes/00_classes/init_spec.rb

# Puppet lint
bundle exec rake lint

# Ruby lint
bundle exec rake rubocop

# Regenerate REFERENCE.md from puppet-strings docstrings
puppet strings generate --format markdown --out REFERENCE.md

# Run the default beaker acceptance suite
bundle exec rake beaker:suites[default]
```

Relevant gem pins (from `Gemfile`): `puppetlabs_spec_helper ~> 8.0.0`,
`simp-rake-helpers ~> 5.24.0`, `simp-rspec-puppet-facts ~> 4.0.0`,
`simp-beaker-helpers ~> 2.0.0`. Rubocop is pinned to `~> 1.88.0`. The `:test`
group loads **both** `openvox` and `puppet` gems, defaulting to the `>= 8 < 9`
range (`Gemfile`). `spec/spec_helper.rb` uses
`require 'puppetlabs_spec_helper/module_spec_helper'` (`spec_helper.rb`).

## Conventions

- Preserve the `@summary` / `@param` puppet-strings docstrings — they drive
  `REFERENCE.md`. Regenerate `REFERENCE.md` after changing docs or parameters.
- Every setting is three-state (`undef` leaves it alone, a value writes it,
  `'absent'` removes it) and edited in place; never render a package-shipped
  file whole. Gate config edits on the package (`require =>
  Class['pupmod::master::install']`) for noop-safety.
- Write `puppet.conf` settings through the `pupmod::conf` define rather than
  managing `ini_setting` directly, so the `master`→`server` rewrite and service
  triggers stay consistent (`conf.pp`).
- Continue routing SIMP feature toggles through
  `simplib::lookup('simp_options::*', { 'default_value' => ... })` with an explicit
  default rather than assuming `simp_options` is included.
- Keep the `pupmod::pass_two` second-pass mechanism intact for any logic that must
  observe whether PE classes are in the catalog (`init.pp`,
  `pass_two.pp`).
- Route puppetserver config-changing resources through
  `notify => Class['pupmod::master::service']` so the server reloads, matching the
  existing resources in `manifests/master.pp` and `manifests/master/`.
- Keep path/OS defaults and the PE class map in module data under `data/`, not
  hard-coded in the manifests.
- `Gemfile`, `spec/spec_helper.rb`, `.gitignore`, `.pdkignore`, and
  `.github/workflows/pr_tests.yml` carry a **puppetsync** notice — they are
  baseline-managed and the next sync overwrites local edits. Push changes to those
  files upstream to the baseline, not here.
- Match the existing 2-space Puppet indentation and aligned-arrow parameter style
  used throughout `manifests/`.
