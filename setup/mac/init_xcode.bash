#!/usr/bin/env bash

set -euxo pipefail

feedback () {
  echo -n $'\033[32m'
  echo "$0"
  echo -n $'\033[00m'
}

die () {
  echo >&2 "$@"
}

pull_xcode_or_clt () {
  local file="$1"
  shift

  local full_version="$1"
  shift

  local hash_expect="$1"
  shift

  local destination="$1"
  shift

  if ! [ -f "$destination" ]; then
    die "Please place the $file at $destination before running this script"
  fi

  local destdir
  destdir="$( dirname "$destination" )"
  readonly destdir

  local destfile
  destfile="$( basename "$destination" )"
  readonly destfile

  feedback "Verifying the $file..."
  echo "$hash_expect  $destfile" > "$destination.sha256sum"
  shasum -a 1 --check "$destination.sha256sum"
}

# Succeeds if the first argument is vercmp-greater-or-equal-to the second
# argument.
version_is_at_least () {
  local lhs="$1"
  shift

  local rhs="$1"
  shift

  local lower
  lower="$( printf "%s\n%s" "$lhs" "$rhs" | \
    sort --version-sort | \
    head --lines=1 )"
  readonly lower

  # Second is "lower", so the first is at least its value, therefore succeed.
  if [ "$lower" -eq "$rhs" ]; then
    return 0
  fi
  return 1
}

readonly version="$1"
shift || die "'version' argument is required"

curdir="$( dirname "$0" )"
readonly curdir

readonly xcode_hashes="$curdir/xcode_hashes.csv"

feedback "Pulling metadata from the file..."
cat "$xcode_hashes"
xcode_full_version="$(
  grep --fixed-strings "$version," "$xcode_hashes" | \
    cut -d, -f2 )"
readonly xcode_full_version
xcode_hash_expect="$(
  grep --fixed-strings "$version," "$xcode_hashes" | \
    cut -d, -f3 )"
readonly xcode_hash_expect
readonly clt_hash_except="$(
  grep --fixed-strings "$version," "$xcode_hashes" | \
    cut -d, -f4 )"

feedback "Verifying the metadata is present..."
if [ -z "$xcode_full_version" ]; then
  die "Unknown installer version for version '$version'"
fi
if [ -z "$xcode_hash_expect" ]; then
  die "Unknown installer hash for version '$version'"
fi
if [ -z "$clt_hash_expect" ]; then
  die "Unknown command line tools hash for version '$version'"
fi

feedback "Checking if Xcode is already installed..."
readonly xcode_root="/Applications/Xcode-$version.app"
if ! [ -d "$xcode_root/Contents/Developer" ]; then
  readonly installer_loc="Xcode_$version.xip"
  readonly clt_loc="Command_Line_Tools_for_Xcode_$version.dmg"

  feedback "Fetching the installer and command line tools..."
  pull_xcode_or_clt "Xcode installer" \
    "$xcode_full_version" "$xcode_hash_expect" "$installer_loc"
  pull_xcode_or_clt "Command Line Tools" \
    "$xcode_full_version" "$clt_hash_expect" "$clt_loc"

  feedback "Installing command line tools..."
  hdiutil attach "$clt_loc"
  readonly clt_volume="/Volumes/Command\ Line\ Developer\ Tools"
  sudo installer -package \
    "$clt_volume/Command\ Line\ Tools.pkg" \
    -target /
  hdiutil detach "$clt_volume"

  feedback "Extracting the installer..."
  xip -x "$installer_loc"

  if ! [ -d "Xcode.app" ]; then
    die "Failed to extract the Xcode application"
  fi

  feedback "Removing the installer and command line tools..."
  rm "$installer_loc" "$clt_loc"

  # Move the installer to "/Applications".
  feedback "Moving Xcode application..."
  sudo mv --no-target-directory --verbose "Xcode.app" "$xcode_root"
fi

feedback "Performing first-run tasks..."
readonly xcode_developer="$xcode_root/Contents/Developer"
readonly xcode_resources="$xcode_root/Contents/Resources"

feedback "Accepting the license..."
sudo "$xcode_developer/usr/bin/xcodebuild" -license accept

feedback "Checking first-launch status..."
if ! env DEVELOPER_DIR="$xcode_developer" xcodebuild -checkFirstLaunchStatus; then
  feedback "Running first-launch setup..."
  sudo env DEVELOPER_DIR="$xcode_developer" xcodebuild -runFirstLaunch
fi

feedback "Building a list of packages to install..."
packages=(
  CoreTypes # Xcode 14+
)

feedback "Checking for XcodeSystemResources version..."
xsr_version="$( pkgutil --pkg-info com.apple.pkg.XcodeSystemResources | \
  sed -n -e '/version/s/version: //p' )"
readonly xsr_version
if version_is_at_least "$xsr_version" "$version"; then
  packages+=("XcodeSystemResources")
fi

readonly packages

# Install the needed packages.
for package in "${packages[@]}"; do
  package_path="$xcode_resources/Packages/$package.pkg"
  if ! [ -f "$package_path" ]; then
    feedback "WARNING: Missing installer for the '$package' package"
    continue
  fi

  feedback "Installing $package package..."
  sudo /usr/sbin/installer -dumplog -verbose \
    -pkg "$package_path" \
    -target /
done

# Set the derived data location to be relative. This keeps files that Xcode
# makes in the CI directories that get cleaned up rather than accumulating
# system-wide.
feedback "Setting DerivedData location..."
defaults write com.apple.dt.Xcode IDECustomDerivedDataLocation .XcodeDerivedData
