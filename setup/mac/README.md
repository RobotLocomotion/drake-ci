## macOS provisioning scripts

### `xcode_hashes.csv`

This file contains 4 columns:

- The `MAJOR.MINOR` version of Xcode.
- The actual version present in the installer's filename (e.g., `14.0.1` is
  sometimes the official release).
- The SHA256 of the Xcode installer.
- The SHA256 of the Xcode Command Line Tools.

### `init_xcode.bash`

A script to install and setup an Xcode version without (much) interaction. It
uses `sudo` internally for some steps, so password prompts may appear.

It accepts a single argument, the `MAJOR.MINOR` version of the Xcode to install.
It will install it to `/Applications/Xcode-MAJOR.MINOR.app` to avoid collisions
between Xcode versions on the same machine.

### `base_image_init_script.bash`

A script to perform initial system configuration. It uses `sudo` internally for
some steps, so password prompts may appear.

It accepts no arguments.
