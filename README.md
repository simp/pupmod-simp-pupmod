[![License](https://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/73/badge)](https://bestpractices.coreinfrastructure.org/projects/73)
[![Puppet Forge](https://img.shields.io/puppetforge/v/simp/pupmod.svg)](https://forge.puppetlabs.com/simp/pupmod)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/simp/pupmod.svg)](https://forge.puppetlabs.com/simp/pupmod)
[![Build Status](https://travis-ci.org/simp/pupmod-simp-pupmod.svg)](https://travis-ci.org/simp/pupmod-simp-pupmod)

#### Table of Contents

<!-- vim-markdown-toc GFM -->

* [Overview](#overview)
* [This is a SIMP module](#this-is-a-simp-module)
* [Module Description](#module-description)
* [Upgrade Considerations](#upgrade-considerations)

<!-- vim-markdown-toc -->


## Overview

## This is a SIMP module

This module is a component of the [System Integrity Management Platform](https://simp-project.com),
a compliance-management framework built on Puppet.

If you find any issues, they can be submitted to our [JIRA](https://simp-project.atlassian.net/).

Please read our [Contribution Guide](https://simp.readthedocs.io/en/stable/contributors_guide/index.html).

## Module Description

See [REFERENCE.md](REFERENCE.md) for more details.

## Upgrade Considerations

### Upgrading From 7.3.0 Or Earlier

Legacy auth.conf, `/etc/puppetlabs/puppet/auth.conf`, has been deprecated.
`pupmod-simp-pupmod` will back up legacy puppet auth.conf after upgrade.

The puppetserver's auth.conf is now managed by Puppet. You will need to
re-produce any custom work done to legacy auth.conf in the new auth.conf, via
the `puppet_authorization::rule` define.  The stock rules are managed in
`pupmod::master::simp_auth`.
