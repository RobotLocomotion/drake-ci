#!/usr/bin/env python

# BSD 3-Clause License
#
# Copyright (c) 2022, Massachusetts Institute of Technology.
# Copyright (c) 2022, Toyota Research Institute.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

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

SUPPORTED_TRACKS = {'nightly', 'continuous', 'experimental', 'staging'}


def canonical_uri(*, name, options, scheme, domain, escape: bool):
    """
    Returns the URI for the specified parameters.
    """
    path = f'drake/{options.track}/{name}'
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
        f"max_age only supports nightly and continuous, not {options.track}")


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
            subprocess.run(command, check=True, capture_output=True)
            break

        except subprocess.CalledProcessError as e:
            if attempt < MAX_ATTEMPTS:
                sleep(BACKOFF_DELAY)
            else:
                print(e.stdout)
                print(e.stderr)
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
    Uploads an artifact (and checksums) to AWS S3. Depending on the CI track,
    also uploads a copy as 'latest'.
    """
    path = options.artifact
    name = os.path.basename(path)

    upload(path, name, options)
    upload_checksum(path, name, options)

    # For nightly and continuous, upload a 'latest' artifact as well.
    if options.nightly or options.continuous:
        # Names are expected too like like one of:
        #
        # TGZ:
        #   drake-<YYYYMMDD>-<codename>.tar.gz (nightly)
        #   drake-<YYYYMMDDHHMMSS>-<hash>-<codename>.tar.gz
        # Deb:
        #   drake-dev_0.0.<YYYYMMDD>-1_amd64-<codename>.deb (nightly)
        #   drake-dev_0.0.<YYYYMMDDHHMMSS>-<commit>-1_amd64-<codename>.deb
        # Wheel:
        #   drake-0.0.YYYY.M.D.h.m.s+git<commit>-cp39-cp39-<platform>.whl
        # Generally:
        #   drake-[dev_]<version>[-<commit>]-<stuff>
        #
        # A 'latest' artifact should preserve '<stuff>' unaltered, but replace
        # the version/date/sha with 'latest'. This regex matches the above and
        # allows us to extract the '<stuff>' portion of the name.
        m = re.match(r'^(drake-(dev_)?)[^-]+(-[0-9a-f]{40})?-(.*)$', name)
        if m is not None:
            prefix = m.group(1)
            residue = m.group(4)
            name = f'{prefix}latest-{residue}'
            expiration = max_age(options)

            upload(path, name, options, expiration=expiration)
            upload_checksum(path, name, options, expiration=expiration)
        else:
            raise RuntimeError(
                f"Failed to transform version in artifact {name} to 'latest'.")


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
        '--track', type=str.lower, required=True, choices=SUPPORTED_TRACKS,
        help='CI track of artifact')
    parser.add_argument(
        '--log', type=str, metavar='LOGFILE', dest='logfile',
        help='Append list of uploaded URIs to %(metavar)s')

    options = parser.parse_args(args)

    for t in SUPPORTED_TRACKS:
        setattr(options, t, options.track == t)

    if not os.path.exists(options.artifact):
        parser.error(f'Artifact {options.artifact!r} does not exist')

    upload_artifacts(options)


if __name__ == '__main__':
    main(sys.argv[1:])
