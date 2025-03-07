#!/usr/bin/env python3

"""Helper script for Anzu setup."""

import argparse
import os
import subprocess
import sys


def _fix_broken():
    print("+ apt-get install --fix-broken")
    subprocess.check_call(['apt-get', 'install', '--fix-broken', '-q'])


def _parse_debname(on_error, uri):
    """Splits a *.deb URI into relevant pieces."""

    # Grab just the filename, not the full URL.
    basename = os.path.basename(uri)

    # Bazelisk URIs follow a weird convention that needs special handling.
    if '/bazelisk-' in uri:
        package_name = "bazelisk"
        uri_tokens = uri.split('/')
        assert 'download' in uri_tokens, uri
        version = uri_tokens[uri_tokens.index('download') + 1]
        assert version.startswith('v'), uri
        desired_version = version[1:]
        return basename, package_name, desired_version

    # Parse basenames that look like 'lcm_1.3.95.20180523-1_amd64.deb'.
    # (Bazel debs are unusual by ending with "-linux-x86_64".)
    package_name, desired_version = None, None
    for known_arch in ['_amd64.deb', '-linux-x86_64.deb']:
        if basename.endswith(known_arch):
            tokens = basename[:-len(known_arch)].split('_')
            if len(tokens) != 2:
                on_error('Could not parse name and version "{}"'.format(
                    basename))
            package_name, desired_version = tokens
            break
    if not package_name:
        on_error('Unknown architecture for "{}"'.format(basename))

    return basename, package_name, desired_version


def _get_installed_version(package_name):
    """Returns the installed version of a package, or None."""

    result = subprocess.run(
        ['dpkg-query', '--showformat=${db:Status-Abbrev} ${Version}',
         '--show', package_name],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        encoding="utf-8")
    if result.returncode != 0:
        return None
    status, version = result.stdout.split()
    if status != "ii":
        return None
    return version


def _fetch(on_error, uri, sha256):
    """Downloads a *.deb URI and verifies its checksum."""

    _, package_name, desired_version = _parse_debname(on_error, uri)
    deb_filename = '/tmp/{}_{}_amd64.deb'.format(package_name, desired_version)
    subprocess.check_call(['wget', '--quiet', '-O', deb_filename, uri])
    sha_filename = deb_filename + '.sha256'
    with open(sha_filename, 'w') as sha_file:
        sha_file.write(sha256 + '  ' + deb_filename + '\n')
    subprocess.check_call(['sha256sum', '--check', '--quiet', sha_filename])
    return deb_filename


def _do_action_fetch(parser, uri, sha256):
    """Handles a --fetch command from the user."""
    tmpname = _fetch(parser.error, uri, sha256)
    print(tmpname)


def _do_action_install(parser, uri, sha256):
    """Handles an --install command from the user."""

    # See what's installed already.
    basename, package_name, desired_version = _parse_debname(
        parser.error, uri)
    installed_version = _get_installed_version(package_name)
    if installed_version == desired_version:
        print('debtool: {} is already at the desired version {}'.format(
            package_name, installed_version))
        return

    # Install the deb (even though we're possibly missing its dependencies).
    tmpname = _fetch(parser.error, uri, sha256)
    print('+ dpkg --install ' + tmpname)
    subprocess.call(['dpkg', '--install', tmpname])

    # The fix_broken call should be able to add the missing dependencies.
    _fix_broken()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    positionals = 'URI SHA256'
    parser.add_argument(
        '--fetch', action='store_true',
        help='Download the *.deb URIs given on the command line.')
    parser.add_argument(
        '--install', action='store_true',
        help='Download and install the *.deb URIs given on the command line.')
    parser.add_argument(
        positionals, nargs='+',
        help='Where to download a *.deb from, and its expected sha256sum.')
    args = parser.parse_args()
    args.uris = getattr(args, positionals)[::2]
    args.sha256s = getattr(args, positionals)[1::2]
    if len(args.uris) != len(args.sha256s):
        parser.error('Mismatched URI/SHA256 pairing')

    if args.install:
        if os.geteuid() != 0:
            print("error: --install mode requires root permissions")
            sys.exit(1)
        # Start from a stable point.  If this is broken, all else is hopeless.
        _fix_broken()

    # Process each URI/checksum pair on the command line.
    for uri, sha256 in zip(args.uris, args.sha256s):
        if len(sha256) != 64:
            parser.error('Malformed sha256 "{}"'.format(sha256))
        _parse_debname(parser.error, uri)  # For uri errors side effects only.

        # Perform the user's requested action.
        if args.fetch:
            _do_action_fetch(parser, uri, sha256)
        elif args.install:
            _do_action_install(parser, uri, sha256)
        else:
            parser.error('No action specified; did you want --install?')


if __name__ == '__main__':
    main()
