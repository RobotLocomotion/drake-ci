#!/usr/bin/env python

import argparse
import datetime
import hashlib
import os
import re
import subprocess
import sys
import urllib.parse

from time import sleep

ARCHIVE_STORAGE_CLASS = 'STANDARD'
MAX_ATTEMPTS = 3
BACKOFF_DELAY = 15

SUPPORTED_GROUPS = {'nightly', 'continuous', 'experimental', 'staging'}


def canonical_uri(*, name, options, scheme, domain, escape: bool):
    """
    Returns the URI for the specified parameters.
    """
    path = f'drake/{options.group}/{name}'
    if escape:
        path = urllib.parse.quote(path)
    return urllib.parse.urlunsplit((scheme, domain, path, '', ''))


def aws_uri(name, options):
    """
    Returns the AWS S3 URI for the specified `name` and `options`.
    """
    return canonical_uri(name=name, options=options, scheme='s3',
                         domain=f'{options.bucket}', escape=False)


def download_uri(name, options):
    """
    Returns the public-facing download URI for the specified `name` and
    `options`.
    """
    return canonical_uri(name=name, options=options, scheme='https',
                         domain=f'{options.bucket}.csail.mit.edu',
                         escape=True)


def max_age(options):
    """
    Returns the desired Max-Age browser cache duration in seconds as an int.
    This function should only be used for 'latest' uploads for nightly and
    continuous builds.
    """
    def to_seconds(**kwargs):
        return int(datetime.timedelta(**kwargs).total_seconds())

    # NOTE: we need nightly artifacts specifically to expire fairly quickly,
    # otherwise drake-external-examples may receive a cached version from
    # Amazon CloudFront (default is 24 hours when not specified):
    # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Expiration.html
    if options.nightly or options.continuous:
        return to_seconds(minutes=30)

    raise ValueError(
        f"max_age only supports nightly and continuous, not {options.group}")


def upload(path, name, options, *, expiration=None):
    """
    Attempts to upload a specific artifact to AWS S3. Tries up to
    `MAX_ATTEMPTS` times before giving up. This is the internal helper function
    used by the more general wrappers.

    When provided, `expiration` (an int representing seconds) will be added to
    the s3 cache control for content Max-Age http headers.
    """
    command = [
        options.aws, 's3', 'cp',
        '--only-show-errors',
        '--acl', 'public-read',
        '--storage-class', ARCHIVE_STORAGE_CLASS]
    if expiration is not None:
        command += ['--cache-control', f'max-age={expiration}']
    command += [path, aws_uri(name, options)]

    print(f'-- Uploading {name} to AWS S3...', flush=True)
    print(command, flush=True)

    attempt = 0
    while True:
        try:
            attempt += 1
            subprocess.check_call(command)
            break

        except Exception:
            if attempt < MAX_ATTEMPTS:
                sleep(BACKOFF_DELAY)
            else:
                print(f'ERROR: Artifact {path} could not be uploaded '
                      f'after {MAX_ATTEMPTS} attempts', file=sys.stderr)
                sys.exit(1)

    uri = download_uri(name, options)
    print(f'-- Upload complete: {uri}', flush=True)
    if options.logfile is not None:
        with open(options.logfile, 'a') as lf:
            print(uri, file=lf)


def upload_checksum(path, name, options, *, expiration=None):
    """
    Computes the checksum of an artifact, creates a checksum file, and uploads
    the checksum file to AWS S3.

    When provided, `expiration` (an int representing seconds) will be added to
    the s3 cache control for content Max-Age http headers.
    """
    checksum = hashlib.sha512()

    with open(path, mode='rb') as f:
        while True:
            data = f.read(64 << 10)
            if not data:
                break
            checksum.update(data)

    checksum_path = f'{path}.sha512'
    with open(checksum_path, mode='w') as f:
        f.write(f'{checksum.hexdigest()}  {name}\n')

    upload(checksum_path, f'{name}.sha512', options, expiration=expiration)


def upload_artifacts(options):
    """
    Uploads an artifact (and checksums) to AWS S3. Depending on the CI group,
    also uploads a copy as 'latest'.
    """
    path = options.artifact
    name = os.path.basename(path)

    upload(path, name, options)
    upload_checksum(path, name, options)

    # For Nightly and Continuous, upload a 'latest' artifact as well (but not
    # for Documentation jobs, which publish instead to the site instead).
    #
    # We'll compute the 'latest' name even in jobs we're not going to upload it
    # so that we can verify the logic during Experimental testing.
    #
    # Names are expected to look like one of:
    #
    # TGZ:
    #   drake-0.0.YYYYMMDD[a1]-<codename>.tar.gz (nightly)
    #   drake-0.0.YYYYMMDD.HHMMSS[a1]+git<commit>-<codename>.tar.gz
    # Deb:
    #   drake-dev_0.0.YYYYMMDDa1-1_<arch>-<codename>.deb (nightly)
    #   drake-dev_0.0.YYYYMMDD.HHMMSS[a1]+git<commit>-1_<arch>-<codename>.deb
    # Wheel:
    #   drake-0.0.YYYYMMDDD[a1]-cp312-cp312-<platform>.whl (nightly)
    #   drake-0.0.YYYYMMDDD.HHMMSS[a1]+git<commit>-cp312-cp312-<platform>.whl
    # Documentation (Continuous / Experimental only):
    #   drake-doc-0.0.YYYYMMDD.HHMMSS+git<commit>.tar.gz
    #
    # Those all (except for Documentation) generally match the pattern:
    #   drake-[dev_]<version>[+git<commit>]-<stuff>
    #
    # A 'latest' artifact should preserve '<stuff>' unaltered, but replace the
    # version/date/sha with 'latest'. This regex matches the above and allows us
    # to extract the '<stuff>' portion of the name.
    #
    # The optional "a1" component denotes our nanobind alpha artifacts. These
    # should NOT be published with a 'latest' artifact.
    #
    if name.startswith('drake-doc-'):
        print('Not uploading a "latest" alias for a Documentation build')
        return
    m = re.match(r'^(drake-(dev_)?)([^-]+)-(.*)$', name)
    assert m, f'Could not decompose {name}'
    prefix, _, version, residue = m.groups()
    if version.split('+')[0].endswith('a1'):
        print('Not uploading a "latest" alias for a Nanobind build')
        return
    new_name = f'{prefix}latest-{residue}'
    if options.nightly or options.continuous:
        expiration = max_age(options)
        upload(path, new_name, options, expiration=expiration)
        upload_checksum(path, new_name, options, expiration=expiration)
    else:
        print(f'Not uploading "latest" alias {new_name} during '
              f'non-Nightly, non-Continuous --group={options.group}')


def main(args):
    parser = argparse.ArgumentParser()

    parser.add_argument(
        'artifact', type=str,
        help='Artifact to be uploaded')
    parser.add_argument(
        '--aws', type=str, default='aws',
        help='Path to AWS executable')
    parser.add_argument(
        '--bucket', type=str, required=True,
        help='Name of target AWS bucket')
    parser.add_argument(
        '--group', type=str.lower, required=True, choices=SUPPORTED_GROUPS,
        help='CI group of artifact')
    parser.add_argument(
        '--log', type=str, metavar='LOGFILE', dest='logfile',
        help='Append list of uploaded URIs to %(metavar)s')

    options = parser.parse_args(args)

    for g in SUPPORTED_GROUPS:
        setattr(options, g, options.group == g)

    if not os.path.exists(options.artifact):
        parser.error(f'Artifact {options.artifact!r} does not exist')

    upload_artifacts(options)


if __name__ == '__main__':
    main(sys.argv[1:])
