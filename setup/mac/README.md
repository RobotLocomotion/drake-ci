## macOS provisioning scripts

### `xcode_hashes.csv`

This file contains 5 columns:

- The `MAJOR.MINOR` version of Xcode and Command Line Tools.
- The actual version present in the installer's filename (e.g., `14.0.1` is
  sometimes the official release).
- The SHA256 of the Xcode installer.
- The SHA256 of the Xcode Command Line Tools.
- The `MAJOR` version of macOS for which this Xcode should be set as the
  default (i.e., pointed to by `/Applications/Xcode.app`).

### `init_xcode`

A script to install and setup an Xcode version without (much) interaction. It
uses `sudo` internally for some steps, so password prompts may appear.

It accepts a single argument, the `MAJOR.MINOR` version of the Xcode to install.
It will install it to `/Applications/Xcode-MAJOR.MINOR.app` to avoid collisions
between Xcode versions on the same machine.

### `ami_init_script`

A script to perform initial system configuration. It uses `sudo` internally for
some steps, so password prompts may appear.

It accepts no arguments.

### `provision_image`

A script to perform image provisioning. It installs prerequisite packages for
drake-ci and drake.

It accepts no arguments.
