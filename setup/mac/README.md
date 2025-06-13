## macOS provisioning scripts

### `xcode_hashes.csv`

This file contains 3 columns:

- The `MAJOR.MINOR` version of Xcode.
- The actual version present in the installer's filename (e.g., `14.0.1` is
  sometimes the official release).
- The sha1 hash of the installer for verification purposes.
