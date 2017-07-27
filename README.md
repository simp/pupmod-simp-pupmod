[![License](http://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html) [![Build Status](https://travis-ci.org/simp/pupmod-simp-pupmod.svg)](https://travis-ci.org/simp/pupmod-simp-pupmod) [![SIMP compatibility](https://img.shields.io/badge/SIMP%20compatibility-4.2.*%2F5.1.*-orange.svg)](https://img.shields.io/badge/SIMP%20compatibility-4.2.*%2F5.1.*-orange.svg)

## This is a SIMP module
This module is a component of the [System Integrity Management Platform](https://github.com/NationalSecurityAgency/SIMP), a compliance-management framework built on Puppet.

If you find any issues, they can be submitted to our [JIRA](https://simp-project.atlassian.net/).

Please read our [Contribution Guide](https://simp-project.atlassian.net/wiki/display/SD/Contributing+to+SIMP) and visit our [developer wiki](https://simp-project.atlassian.net/wiki/display/SD/SIMP+Development+Home).

## Upgrading From 7.3.0 Or Earlier

If you intend to upgrade from version 7.3.0-0 or earlier, you should:

1. Back up legacy puppet auth.conf, `<puppet confdir>/auth.conf`, before upgrade.

2. Re-produce any custom work done to legacy auth.conf in the new auth.conf, via the `puppet_authorization::rule` define.  The stock rules are managed in `pupmod::master::simp_auth`.
