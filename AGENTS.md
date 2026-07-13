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
  `unless $mock` (`init.pp`); first runs `simplib::assert_metadata($module_name)`
  (`init.pp`) and `assert_type` on `$classfile` (`init.pp`). Orchestration:
  optionally `include 'haveged'` if `$haveged` (`init.pp`); always
  `include pupmod::agent::install` (`init.pp`); `include 'pupmod::master'` when
  `$enable_puppet_master` (`init.pp`); always `include 'pupmod::agent::cron'`
  (`init.pp`). Manages `service { 'puppet' }` — running+enabled only when
  `$daemonize`, otherwise stopped (`init.pp`), subscribed to
  `puppet.conf`. Emits many `pupmod::conf` settings (splay, syslogfacility,
  certname, vardir, runinterval, ssldir, digest_algorithm, etc.,
  `init.pp`) plus `daemonize` (`init.pp`) and an optional
  `splaylimit` (`init.pp`). Handles `$set_environment` (`init.pp`),
  SELinux boolean `puppetagent_manage_all_files` (`init.pp`), and
  systemd-tmpfile log purging (`init.pp`). See the pass-two note below.
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
  `ca_server`, ports, and report settings for FOSS/OpenVox
  (`pass_two.pp`); builds PE user/service/firewall data from
  `$pe_classlist` (`pass_two.pp`); and **`fail()`s if both
  `puppet_enterprise::profile::master` and `pupmod::master` are classified**
  (`pass_two.pp`).

Server side (`pupmod::master*`):

- **`pupmod::master` (`manifests/master.pp`)** — Public. `inherits pupmod`
  (`master.pp`), `unless $mock` (`master.pp`) it includes and orders the
  six master subclasses (`master.pp`), writes the puppetserver HOCON/EPP
  config files (`ca.cfg`, `logback.xml`, `ca.conf`, `puppetserver.conf`,
  `web-routes.conf`, `webserver.conf`, `master.pp`), and emits many
  `pupmod::conf` server-section settings. Notable branches: **`keylength` is 2048
  under FIPS else 4096** (`if $pupmod::fips`, `master.pp`); the deprecated
  `[master] ca` setting is version-gated (`master.pp`); a **CVE-2020-7942
  warning** fires when `$strict_hostname_checking` is false
  (`master.pp`); optional `auditd` rule (`master.pp`) and `iptables`
  openings for the master/CA ports when `$firewall` (`master.pp`);
  `autosign_hosts` realized via `ensure_resource` (`master.pp`).
- **`pupmod::master::install` (`manifests/master/install.pp`)** — Private
  (`assert_private()`, `master/install.pp`). Installs the server package
  (`openvox-server`, or `pe-puppetserver` on PE). For OpenVox it either installs a
  directly-supplied RPM (`pupmod::openvox_rpm_path`) or the OpenVox release RPM +
  server package from `pupmod::openvox_base_url` (`master/install.pp`).
- **`pupmod::master::service` (`manifests/master/service.pp`)** — Public.
  Manages `service { 'puppetserver' }` (running+enabled) on non-PE
  (`master/service.pp`). Most config resources `notify` this class.
- **`pupmod::master::base` (`manifests/master/base.pp`)** — Public. Static
  helper files/scripts: `puppetserver_reload` / `puppetserver_clear_environment_cache`
  scripts, the environments dir, the `puppet` user, and a base `auth.conf`
  (`puppet_authorization`, `base.pp`).
- **`pupmod::master::sysconfig` (`manifests/master/sysconfig.pp`)** —
  Public. `inherits pupmod`, `unless $mock`. Computes JVM heap
  (`pupmod::java_max_memory`) and writes `/etc/sysconfig/puppetserver` (FOSS) or PE
  ini subsettings (`sysconfig.pp`); selects the JRuby jar from the
  `puppetserver_jruby` fact (`sysconfig.pp`).
- **`pupmod::master::reports` (`manifests/master/reports.pp`)** — Private
  (`assert_private()`, `master/reports.pp`). `inherits pupmod::master`. Purges
  old reports via a `systemd::tmpfile` (`reports.pp`); `$port`/`$purge_verbose`
  are deprecated no-ops.
- **`pupmod::master::generate_types` (`manifests/master/generate_types.pp`)** —
  Public. Runs `puppet generate types` via systemd path/service units triggered on
  environment/app changes (`generate_types.pp`); **incron support is
  removed** and emits a deprecation `notify` if triggers are disabled
  (`generate_types.pp`), plus a `tidy` of legacy `/etc/incron.d`
  (`generate_types.pp`).
- **`pupmod::master::simp_auth` (`manifests/master/simp_auth.pp`)** —
  Public. Adds SIMP-specific `puppet_authorization::rule` entries (pki_files
  cacerts/keydist, krb5 keytabs) to the puppetserver `auth.conf`
  (`simp_auth.pp`) and removes the stray agent-dropped
  `/etc/puppetlabs/puppet/auth.conf` (`simp_auth.pp`).
- **`pupmod::master::autosign` (define, `manifests/master/autosign.pp`)** —
  Public. Adds a `concat::fragment` autosign entry; `fail()`s if `$name` is not a
  valid autosign pattern when no `$entry` is given (`autosign.pp`).
- **`pupmod::master::fileserver_entry` (define,
  `manifests/master/fileserver_entry.pp`)** — Public. Adds a
  `fileserver.conf` `[segment]` via `concat::fragment` (`fileserver_entry.pp`).

Puppet-language functions (`functions/`, all `pupmod::*`): `server_distribution`
(FOSS/OpenVox/PE detection, `functions/server_distribution.pp`), `server_version`,
`java_max_memory`, `max_active_instances`, `reserved_code_cache`. Custom Ruby facts
(`lib/facter/`): `puppet_ruby_dir`, `puppetserver_jruby`, `puppet_service_enabled`,
`puppet_service_started`, `simp_pupmod_serverversion`.

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
- **FIPS lowers the CA keylength to 2048** (`master.pp`) — 2048 under
  `pupmod::fips`, 4096 otherwise. `$pupmod::fips` itself comes from the
  `simp_options::fips` seam (`init.pp`).
- **`$mock` compiles a no-op catalog.** `pupmod`, `pupmod::master`, and
  `pupmod::master::sysconfig` wrap their bodies in `unless $mock`
  (`init.pp`, `master.pp`, `sysconfig.pp`) — used for testing/inspection.
- **`master` → `server` section rewriting is pervasive.** `pupmod::conf` rewrites
  the `master` section to `server` and cleans the stale entry (`conf.pp`);
  many manifests use `pick($facts.dig('puppet_settings','server',...),
  $facts.dig('puppet_settings','master',...))` to bridge the Puppet 6.19 rename
  (e.g. `base.pp`, `master.pp`, `pass_two.pp`).
- **CVE-2020-7942 is deliberately guarded.** Turning off
  `strict_hostname_checking` emits a warning `notify` (`master.pp`); it
  defaults to `true`.
- **`simp/simp_options` is NOT a declared dependency** in `metadata.json`, yet the
  manifests consume the `simp_options::*` seam via `simplib::lookup` (provided by
  `simp/simplib`). `simp_options` appears only as a fixture (`.fixtures.yml`).
  The `default_value` in each `simplib::lookup` call is what makes the classes
  compile without it.
- **Several declared dependencies are used conditionally.** `simp/iptables`
  (`master.pp`, `pass_two.pp`), `simp/haveged` (`init.pp`), and
  `auditd` (`master.pp`, not a declared dep — pulled in only via `$auditd`) are
  `include`d only inside feature branches. `simp/pki` is a declared dependency but
  no `pki::` call appears in `manifests/` (retained as SIMP baseline / referenced by
  the `simp_auth` pki_files rules by path).
- **`data/os/*.yaml` files exist for AlmaLinux/CentOS/OracleLinux/RedHat/Rocky but
  only up to major 8/9.** There are no `-10` per-release data files even though the
  support matrix lists EL10; those fall through to the OS-family / `common.yaml`
  tiers (`hiera.yaml`).

## The `simp_options` / `simplib::lookup` seam

The SIMP feature-toggle seam. All calls are in `manifests/init.pp` and
`manifests/master.pp`:

| File | Key | `default_value` |
|------|-----|-----------------|
| `init.pp` | `simp_options::puppet::ca` | `'$server'` |
| `init.pp` | `simp_options::puppet::ca_port` | `8141` |
| `init.pp` | `simp_options::puppet::server` | `"puppet.${facts['networking']['domain']}"` |
| `init.pp` | `simp_options::haveged` | `false` |
| `init.pp` | `simp_options::fips` | `false` |
| `init.pp` | `simp_options::firewall` | `false` |
| `init.pp` | `simp_options::package_ensure` | `'installed'` |
| `master.pp` | `simp_options::auditd` | `false` |
| `master.pp` | `simp_options::puppet::ca_port` | `8141` |
| `master.pp` | `simp_options::trusted_nets` | `['127.0.0.1','::1']` |
| `master.pp` | `simp_options::firewall` | `false` |
| `master.pp` | `simp_options::syslog` | `false` |
| `master.pp` | `simp_options::package_ensure` | `'installed'` |

Keep routing SIMP feature toggles through `simplib::lookup('simp_options::*', {
'default_value' => ... })` with an explicit default rather than assuming
`simp_options` is included.

## Dependencies

Module dependencies (from `metadata.json`):

- `puppet/systemd` `>= 4.0.2 < 10.0.0` (provides `systemd::timer`,
  `systemd::tmpfile`, `systemd::unit_file`)
- `simp/haveged` `>= 0.4.5 < 1.0.0` (entropy daemon, included only when `$haveged`)
- `puppetlabs/stdlib` `>= 8.0.0 < 10.0.0` (`pick`, `member`, `dirname`, etc.)
- `puppetlabs/inifile` `>= 2.5.0 < 7.0.0` (`ini_setting`/`ini_subsetting` for
  `puppet.conf`)
- `puppetlabs/puppet_authorization` `>= 0.2.0 < 2.0.0`
  (`puppet_authorization` / `puppet_authorization::rule` for `auth.conf`)
- `puppetlabs/hocon` `>= 0.9.3 < 3.0.0` (`hocon_setting` for puppetserver/Facter
  HOCON files)
- `puppetlabs/concat` `>= 6.4.0 < 10.0.0` (autosign/fileserver fragments)
- `simp/iptables` `>= 6.5.3 < 9.0.0` (`iptables::listen::tcp_stateful`, firewall
  branch only)
- `simp/simplib` `>= 4.9.0 < 6.0.0` (`simplib::lookup`, `simplib::assert_metadata`,
  `simplib::rand_cron`, `simplib::cron::to_systemd`, `simplib::in_bolt`, and SIMP
  types)
- `simp/pki` `>= 6.2.0 < 8.0.0` (SIMP baseline; no `pki::` call in `manifests/`)

No `simp.optional_dependencies` block is present in `metadata.json`. `auditd`
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
- `functions/` — Puppet-language functions: `server_distribution.pp`,
  `server_version.pp`, `java_max_memory.pp`, `max_active_instances.pp`,
  `reserved_code_cache.pp`.
- `types/` — custom data types: `Pupmod::CaTTL`, `Pupmod::LogLevel`,
  `Pupmod::Memory`, `Pupmod::ProfilingMode`, `Pupmod::Master::SSLCiphersuites`,
  `Pupmod::Master::SSLProtocols`.
- `lib/facter/` — custom Ruby facts: `puppet_ruby_dir`, `puppetserver_jruby`,
  `puppet_service_enabled`, `puppet_service_started`, `simp_pupmod_serverversion`.
- `templates/` — EPP templates for puppetserver conf.d files, sysconfig,
  systemd units, the agent-cron/careful-shutdown scripts, auditd rules, and the
  fileserver fragment.
- `data/` + `hiera.yaml` — module data (v5 hierarchy: OS name+major → OS name →
  kernel → `common.yaml`). `common.yaml` holds the puppet/puppetserver path
  defaults, `pupmod::facter_options`, and the large `pupmod::pe_classlist` PE
  user/service/firewall map. Per-OS files exist only up to major 8/9.
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
