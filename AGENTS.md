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

The top-level `pupmod` class (`manifests/init.pp:196-452`) is the agent-side
entry point and a "stub" that hooks in the other classes; setting
`pupmod::enable_puppet_master: true` pulls in the server side via
`pupmod::master` (`init.pp:258-260`). Nearly every class honours a `$mock`
parameter that short-circuits the body so the catalog can be compiled/inspected
without declaring real resources (`init.pp:244`, `master.pp:346`,
`sysconfig.pp:88`).

### Business logic

The module has **many** classes/defines. Only five classes call
`assert_private()`; everything else is part of the public API even when it is
"internal" in spirit. Verified `assert_private()` calls: `pupmod::agent::install`
(`agent/install.pp:11`), `pupmod::facter::conf` (`facter/conf.pp:12`),
`pupmod::master::install` (`master/install.pp:21`), `pupmod::master::reports`
(`master/reports.pp:31`), `pupmod::pass_two` (`pass_two.pp:31`).

Agent side:

- **`pupmod` (`manifests/init.pp:196-452`)** — Public entry class. Guarded by
  `unless $mock` (`init.pp:244`); first runs `simplib::assert_metadata($module_name)`
  (`init.pp:245`) and `assert_type` on `$classfile` (`init.pp:250`). Orchestration:
  optionally `include 'haveged'` if `$haveged` (`init.pp:252-254`); always
  `include pupmod::agent::install` (`init.pp:256`); `include 'pupmod::master'` when
  `$enable_puppet_master` (`init.pp:258-260`); always `include 'pupmod::agent::cron'`
  (`init.pp:269`). Manages `service { 'puppet' }` — running+enabled only when
  `$daemonize`, otherwise stopped (`init.pp:262-277`), subscribed to
  `puppet.conf`. Emits many `pupmod::conf` settings (splay, syslogfacility,
  certname, vardir, runinterval, ssldir, digest_algorithm, etc.,
  `init.pp:352-394`) plus `daemonize` (`init.pp:279-284`) and an optional
  `splaylimit` (`init.pp:324-330`). Handles `$set_environment` (`init.pp:332-350`),
  SELinux boolean `puppetagent_manage_all_files` (`init.pp:406-427`), and
  systemd-tmpfile log purging (`init.pp:433-450`). See the pass-two note below.
- **`pupmod::agent::install` (`manifests/agent/install.pp:7-15`)** — Private
  (`assert_private()`, `install.pp:11`). Installs `$package_name`
  (default `$pupmod::agent_package` → `openvox-agent`, `init.pp:224`).
- **`pupmod::agent::cron` (`manifests/agent/cron.pp:134-254`)** — Public. Despite
  the name it configures a **systemd timer** (`systemd::timer`, `cron.pp:229`), not
  cron; it removes legacy `puppetd`/`puppetagent` cron jobs (`cron.pp:153`).
  `$minute` supports randomization algorithms `ip_mod`/`rand`/`sha256` via
  `simplib::rand_cron` (`cron.pp:155-173`), converted to a systemd calendar with
  `simplib::cron::to_systemd` (`cron.pp:190-204`). Disables the `puppet` service in
  the background when cron is enabled (`cron.pp:245-253`, works around PUP-1320).
- **`pupmod::facter::conf` (`manifests/facter/conf.pp:8-48`)** — Private
  (`assert_private()`, `facter/conf.pp:12`). Writes `facter.conf` HOCON settings
  from the `$facter_options` hash (`facter/conf.pp:30-47`). Only included when
  `pupmod::manage_facter_conf` is true (`init.pp:429-431`).
- **`pupmod::conf` (define, `manifests/conf.pp:33-66`)** — Public define. Thin
  wrapper over `ini_setting` on `puppet.conf`; the module's primary way of setting
  puppet.conf keys. `master` section is auto-rewritten to `server`
  (`conf.pp:42-47`) and a matching stale `master`-section entry is removed
  (`conf.pp:58-64`); `environment` is forced into the `agent` section
  (`conf.pp:37`, SIMP-6820).
- **`pupmod::pass_two` (define, `manifests/pass_two.pp:19-224`)** — Private
  (`assert_private()`, `pass_two.pp:31`). Declared virtually and realized
  immediately in `pupmod` (`@pupmod::pass_two { 'main' }` then
  `Pupmod::Pass_two <| |>`, `init.pp:311-322`) to defer its logic to the catalog
  compiler's **second pass** so `defined(Class[...])` PE-detection checks are
  reliable (see the long comment `init.pp:286-309`). Sets `server`/`server_list`,
  `ca_server`, ports, and report settings for FOSS/OpenVox
  (`pass_two.pp:40-96`); builds PE user/service/firewall data from
  `$pe_classlist` (`pass_two.pp:115-133,187-223`); and **`fail()`s if both
  `puppet_enterprise::profile::master` and `pupmod::master` are classified**
  (`pass_two.pp:156-162`).

Server side (`pupmod::master*`):

- **`pupmod::master` (`manifests/master.pp:282-583`)** — Public. `inherits pupmod`
  (`master.pp:339`), `unless $mock` (`master.pp:346`) it includes and orders the
  six master subclasses (`master.pp:347-356`), writes the puppetserver HOCON/EPP
  config files (`ca.cfg`, `logback.xml`, `ca.conf`, `puppetserver.conf`,
  `web-routes.conf`, `webserver.conf`, `master.pp:389-404`), and emits many
  `pupmod::conf` server-section settings. Notable branches: **`keylength` is 2048
  under FIPS else 4096** (`if $pupmod::fips`, `master.pp:502-515`); the deprecated
  `[master] ca` setting is version-gated (`master.pp:456-500`); a **CVE-2020-7942
  warning** fires when `$strict_hostname_checking` is false
  (`master.pp:534-538`); optional `auditd` rule (`master.pp:549-555`) and `iptables`
  openings for the master/CA ports when `$firewall` (`master.pp:557-575`);
  `autosign_hosts` realized via `ensure_resource` (`master.pp:577-581`).
- **`pupmod::master::install` (`manifests/master/install.pp:11-47`)** — Private
  (`assert_private()`, `master/install.pp:21`). Installs the server package
  (`openvox-server`, or `pe-puppetserver` on PE). For OpenVox it either installs a
  directly-supplied RPM (`pupmod::openvox_rpm_path`) or the OpenVox release RPM +
  server package from `pupmod::openvox_base_url` (`master/install.pp:23-45`).
- **`pupmod::master::service` (`manifests/master/service.pp:7-18`)** — Public.
  Manages `service { 'puppetserver' }` (running+enabled) on non-PE
  (`master/service.pp:10-17`). Most config resources `notify` this class.
- **`pupmod::master::base` (`manifests/master/base.pp:3-74`)** — Public. Static
  helper files/scripts: `puppetserver_reload` / `puppetserver_clear_environment_cache`
  scripts, the environments dir, the `puppet` user, and a base `auth.conf`
  (`puppet_authorization`, `base.pp:60-62`).
- **`pupmod::master::sysconfig` (`manifests/master/sysconfig.pp:67-153`)** —
  Public. `inherits pupmod`, `unless $mock`. Computes JVM heap
  (`pupmod::java_max_memory`) and writes `/etc/sysconfig/puppetserver` (FOSS) or PE
  ini subsettings (`sysconfig.pp:114-151`); selects the JRuby jar from the
  `puppetserver_jruby` fact (`sysconfig.pp:135-142`).
- **`pupmod::master::reports` (`manifests/master/reports.pp:24-42`)** — Private
  (`assert_private()`, `master/reports.pp:31`). `inherits pupmod::master`. Purges
  old reports via a `systemd::tmpfile` (`reports.pp:38-41`); `$port`/`$purge_verbose`
  are deprecated no-ops.
- **`pupmod::master::generate_types` (`manifests/master/generate_types.pp:47-162`)** —
  Public. Runs `puppet generate types` via systemd path/service units triggered on
  environment/app changes (`generate_types.pp:76-134`); **incron support is
  removed** and emits a deprecation `notify` if triggers are disabled
  (`generate_types.pp:135-141`), plus a `tidy` of legacy `/etc/incron.d`
  (`generate_types.pp:157-161`).
- **`pupmod::master::simp_auth` (`manifests/master/simp_auth.pp:45-125`)** —
  Public. Adds SIMP-specific `puppet_authorization::rule` entries (pki_files
  cacerts/keydist, krb5 keytabs) to the puppetserver `auth.conf`
  (`simp_auth.pp:69-114`) and removes the stray agent-dropped
  `/etc/puppetlabs/puppet/auth.conf` (`simp_auth.pp:120-124`).
- **`pupmod::master::autosign` (define, `manifests/master/autosign.pp:12-44`)** —
  Public. Adds a `concat::fragment` autosign entry; `fail()`s if `$name` is not a
  valid autosign pattern when no `$entry` is given (`autosign.pp:33-35`).
- **`pupmod::master::fileserver_entry` (define,
  `manifests/master/fileserver_entry.pp:12-34`)** — Public. Adds a
  `fileserver.conf` `[segment]` via `concat::fragment` (`fileserver_entry.pp:30-33`).

Puppet-language functions (`functions/`, all `pupmod::*`): `server_distribution`
(FOSS/OpenVox/PE detection, `functions/server_distribution.pp`), `server_version`,
`java_max_memory`, `max_active_instances`, `reserved_code_cache`. Custom Ruby facts
(`lib/facter/`): `puppet_ruby_dir`, `puppetserver_jruby`, `puppet_service_enabled`,
`puppet_service_started`, `simp_pupmod_serverversion`.

### Gotchas / non-obvious details

- **The "pass two" trick is load-bearing.** `pupmod::pass_two` is declared as a
  virtual resource and realized immediately (`init.pp:311-322`) purely to push its
  logic into the catalog compiler's second pass, so its `defined(Class[...])`
  PE-detection is reliable. Don't "simplify" it into inline code — read the comment
  at `init.pp:286-309`.
- **`pupmod::master` on a PE master is a hard failure.** If both
  `puppet_enterprise::profile::master` and `pupmod::master` are classified,
  `pupmod::pass_two` calls `fail()` (`pass_two.pp:156-162`).
- **`pupmod::agent::cron` is a systemd timer, not cron.** The name is retained for
  backward compatibility (`agent/cron.pp:2-4`); it declares `systemd::timer`
  (`cron.pp:229`) and removes the old cron jobs.
- **FIPS lowers the CA keylength to 2048** (`master.pp:502-507`) — 2048 under
  `pupmod::fips`, 4096 otherwise. `$pupmod::fips` itself comes from the
  `simp_options::fips` seam (`init.pp:221`).
- **`$mock` compiles a no-op catalog.** `pupmod`, `pupmod::master`, and
  `pupmod::master::sysconfig` wrap their bodies in `unless $mock`
  (`init.pp:244`, `master.pp:346`, `sysconfig.pp:88`) — used for testing/inspection.
- **`master` → `server` section rewriting is pervasive.** `pupmod::conf` rewrites
  the `master` section to `server` and cleans the stale entry (`conf.pp:42-64`);
  many manifests use `pick($facts.dig('puppet_settings','server',...),
  $facts.dig('puppet_settings','master',...))` to bridge the Puppet 6.19 rename
  (e.g. `base.pp:12`, `master.pp:343-344`, `pass_two.pp:100-103`).
- **CVE-2020-7942 is deliberately guarded.** Turning off
  `strict_hostname_checking` emits a warning `notify` (`master.pp:534-538`); it
  defaults to `true`.
- **`simp/simp_options` is NOT a declared dependency** in `metadata.json`, yet the
  manifests consume the `simp_options::*` seam via `simplib::lookup` (provided by
  `simp/simplib`). `simp_options` appears only as a fixture (`.fixtures.yml:25`).
  The `default_value` in each `simplib::lookup` call is what makes the classes
  compile without it.
- **Several declared dependencies are used conditionally.** `simp/iptables`
  (`master.pp:558`, `pass_two.pp:211`), `simp/haveged` (`init.pp:253`), and
  `auditd` (`master.pp:550`, not a declared dep — pulled in only via `$auditd`) are
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

| Line | Key | `default_value` |
|------|-----|-----------------|
| `init.pp:197` | `simp_options::puppet::ca` | `'$server'` |
| `init.pp:198` | `simp_options::puppet::ca_port` | `8141` |
| `init.pp:199` | `simp_options::puppet::server` | `"puppet.${facts['networking']['domain']}"` |
| `init.pp:220` | `simp_options::haveged` | `false` |
| `init.pp:221` | `simp_options::fips` | `false` |
| `init.pp:222` | `simp_options::firewall` | `false` |
| `init.pp:225` | `simp_options::package_ensure` | `'installed'` |
| `master.pp:287` | `simp_options::auditd` | `false` |
| `master.pp:288` | `simp_options::puppet::ca_port` | `8141` |
| `master.pp:289` | `simp_options::trusted_nets` | `['127.0.0.1','::1']` |
| `master.pp:309` | `simp_options::firewall` | `false` |
| `master.pp:328` | `simp_options::syslog` | `false` |
| `master.pp:333` | `simp_options::package_ensure` | `'installed'` |

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
(used at `master.pp:550`) and `puppet_enterprise` (detected via `defined()`) are
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
range (`Gemfile:22-33`). `spec/spec_helper.rb` uses
`require 'puppetlabs_spec_helper/module_spec_helper'` (`spec_helper.rb:11`).

## Conventions

- Preserve the `@summary` / `@param` puppet-strings docstrings — they drive
  `REFERENCE.md`. Regenerate `REFERENCE.md` after changing docs or parameters.
- Write `puppet.conf` settings through the `pupmod::conf` define rather than
  managing `ini_setting` directly, so the `master`→`server` rewrite and service
  triggers stay consistent (`conf.pp:33-66`).
- Continue routing SIMP feature toggles through
  `simplib::lookup('simp_options::*', { 'default_value' => ... })` with an explicit
  default rather than assuming `simp_options` is included.
- Keep the `pupmod::pass_two` second-pass mechanism intact for any logic that must
  observe whether PE classes are in the catalog (`init.pp:286-322`,
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
