## macOS provisioning scripts

This directory contains scripts and supporting files to provision macOS images.
macOS CI is currently hosted in AWS, and CI jobs run back-to-back on the same
instance, unlike the workflow for Linux. As such, images are re-provisioned on
a regular basis to keep up with latest system and upstream dependency changes.

These scripts are intended for use by maintainers during re-provisioning
cycles, **not** during regular CI workflows which run on every job.

### `xcode_hashes.csv`

This file contains 5 columns:

- The `MAJOR.MINOR` version of Xcode and Command Line Tools.
- The actual version present in the installer's filename (e.g., `14.0.1` is
  sometimes the official release).
- The SHA256 of the Xcode installer.
- The SHA256 of the Xcode Command Line Tools.
- (Optional) The `MAJOR` version(s) of macOS for which this Xcode should be set
  as the default (i.e., symlinked by `/Applications/Xcode.app`). This field can
  take zero to many values; to provide multiple, use a semicolon-separated list.

### `init_xcode`

A script to install and setup an Xcode version without (much) interaction. It
uses `sudo` internally for some steps, so password prompts may appear.

It accepts a single argument, the `MAJOR.MINOR` version of the Xcode to install.
It will install it to `/Applications/Xcode-MAJOR.MINOR.app` to avoid collisions
between Xcode versions on the same machine.

It is intended to be used each time a new Xcode base image is created.

### `ami_init_script`

A script to perform initial system configuration. It uses `sudo` internally for
some steps, so password prompts may appear.

It accepts no arguments.

It is intended to be used each time a new Xcode base image is created.

### `provision_image`

A script to perform image provisioning. It is expected to be run from within a
drake-ci checkout. After installing prerequisites for drake-ci, it creates a
temporary clone of drake to install its prerequisites also.

It accepts no arguments.

It is intended to be used each time a new provisioned image is created.
