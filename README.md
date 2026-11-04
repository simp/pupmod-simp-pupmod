[![License](https://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/73/badge)](https://bestpractices.coreinfrastructure.org/projects/73)
[![Puppet Forge](https://img.shields.io/puppetforge/v/simp/pupmod.svg)](https://forge.puppetlabs.com/simp/pupmod)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/simp/pupmod.svg)](https://forge.puppetlabs.com/simp/pupmod)
[![Build Status](https://travis-ci.org/simp/pupmod-simp-pupmod.svg)](https://travis-ci.org/simp/pupmod-simp-pupmod)

#### Table of Contents

<!-- vim-markdown-toc GFM -->

* [Overview](#overview)
* [Breaking changes in 13.0.0](#breaking-changes-in-1300)
  * [Path 1: set the parameters you want](#path-1-set-the-parameters-you-want)
  * [Path 2: enforce the `simp:defaults` profile](#path-2-enforce-the-simpdefaults-profile)
* [This is a SIMP module](#this-is-a-simp-module)
* [Module Description](#module-description)
  * [Settings: set, leave alone, or remove](#settings-set-leave-alone-or-remove)
  * [Applying changes while services are unmanaged](#applying-changes-while-services-are-unmanaged)
  * [The puppetserver webserver layout](#the-puppetserver-webserver-layout)
* [Upgrade Considerations](#upgrade-considerations)

<!-- vim-markdown-toc -->


## Overview

`pupmod` manages Puppet itself: the agent (`pupmod`) and, optionally, the
puppet server (`pupmod::master`).

A bare `include pupmod` installs the agent package and does nothing else, and
a bare `include pupmod::master` installs the server package and does nothing
else. Everything else this module can manage is turned on by setting the
parameter that controls it.

## Breaking changes in 13.0.0

Before 13.0.0, `include pupmod` rewrote `puppet.conf`, stopped the `puppet`
service in favor of a systemd timer, wrote `/etc/sysconfig/puppet`, set an
SELinux boolean, purged logs and changed the ownership of the Puppet
directories, and `include pupmod::master` replaced every puppetserver
configuration file, started the service, added the openvox yum repository and
installed helper scripts and systemd units. None of that happens
automatically any more. See the CHANGELOG for the full list.

There are two ways to get that behavior back.

### Path 1: set the parameters you want

Each behavior has a parameter. Set only the ones you want, for example:

```yaml
pupmod::daemonize: false        # stop the daemon and run the agent from a systemd timer
pupmod::runinterval: 1800
pupmod::digest_algorithm: sha256
pupmod::master::service::service_ensure: running
pupmod::master::service::service_enable: true
```

See [REFERENCE.md](REFERENCE.md) for every parameter.

### Path 2: enforce the `simp:defaults` profile

The module ships a [Sicura Compliance Engine](https://github.com/simp/rubygem-simp-compliance_engine)
profile named `simp:defaults` that restores the 12.x behavior. Enable it with
one Hiera key:

```yaml
compliance_engine::enforcement:
  - simp:defaults
```

This needs the `compliance_engine` module and its Hiera backend in your
environment's `hiera.yaml`:

```yaml
  - name: "Compliance Engine"
    lookup_key: "compliance_engine::enforcement"
```

`simp:defaults` is a drop-in restoration of the old behavior, opinionated for
SIMP sites. It turns the disruptive and destructive behavior back on too:
the `puppet` service is stopped in favor of the timer, logs and reports are
purged, the Puppet directories are re-owned, and the openvox release package
is installed. A site that wants the old behavior but safer enables the
profile and then overrides individual parameters in its own Hiera, which
always wins over the profile:

```yaml
compliance_engine::enforcement:
  - simp:defaults
pupmod::purge_logs: false
pupmod::master::install::install_release_package: false
```

The profile does not restore:

* `pupmod::ca_server`, `pupmod::ca_port`, `pupmod::puppet_server` and
  `pupmod::master::ca_port`. They still default to `simp_options::puppet::*`,
  but no longer fall back to `'$server'`, `8141` and `puppet.<domain>`. If you
  don't set `simp_options`, set these parameters yourself. The other
  `simp_options` settings (`firewall`, `auditd`, `syslog`, `haveged`,
  `trusted_nets`) also keep following `simp_options`.
* `stringify_facts`, `trusted_server_facts` and `[server] ca`, which only
  applied to Puppet 5 and older.
* Parts of the old whole-file puppetserver configuration that no parameter
  controlled, such as removing the package's other `JAVA_ARGS` options or
  its `${logappender}` logger. The profile restores each setting a parameter
  controlled, in place.

The profile restores parameter values going forward. It cannot recreate
anything an earlier run removed.

## This is a SIMP module

This module is a component of the [System Integrity Management Platform](https://simp-project.com),
a compliance-management framework built on Puppet.

If you find any issues, they can be submitted to our [JIRA](https://simp-project.atlassian.net/).

Please read our [Contribution Guide](https://simp.readthedocs.io/en/stable/contributors_guide/index.html).

## Module Description

See [REFERENCE.md](REFERENCE.md) for more details.

### Settings: set, leave alone, or remove

Every setting follows the same contract:

* `undef` (the default) leaves the setting alone, whatever its value
* a value writes it, replacing any earlier value
* `'absent'` removes it (`false` for a Boolean that toggles a resource)

So a later Puppet run that no longer sets a parameter does not revert what an
earlier run wrote. Settings are written in place (`ini_setting`,
`hocon_setting`, `augeas`, `file_line`), so the package's settings, and any
an administrator added, are left as they are.

### Applying changes while services are unmanaged

Configuration changes notify `pupmod::master::service`. While
`pupmod::master::service::service_ensure` and `service_enable` are unset, the
module doesn't manage the `puppetserver` service, so changes are written to
disk but not loaded. Apply them with:

```sh
systemctl restart puppetserver   # for JVM settings in /etc/sysconfig/puppetserver
puppetserver reload              # for everything else
```

With `pupmod::master::base::helper_scripts: true`, the module runs
`puppetserver reload` after each change while puppetserver is running.

The agent daemon reads `puppet.conf` changes on its own.

### The puppetserver webserver layout

The package's `webserver.conf` configures a single server. When
`pupmod::master::ca_port` differs from the main server's port, the CA runs as
its own server: the module converts `webserver.conf` to named servers, moving
the existing settings under `base` and adding a `ca` server. The
`puppetserver_webserver` fact tells the module which layout the file uses, so
settings such as `pupmod::master::ssl_protocols` are written where
puppetserver reads them.

## Upgrade Considerations

### Upgrading From 7.3.0 Or Earlier

Legacy auth.conf, `/etc/puppetlabs/puppet/auth.conf`, has been deprecated.
`pupmod-simp-pupmod` will back up legacy puppet auth.conf after upgrade.

The puppetserver's auth.conf is now managed by Puppet. You will need to
re-produce any custom work done to legacy auth.conf in the new auth.conf, via
the `puppet_authorization::rule` define.  The stock rules are managed in
`pupmod::master::simp_auth`.
