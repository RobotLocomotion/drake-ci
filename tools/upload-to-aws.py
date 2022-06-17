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
import tempfile

from time import sleep

aws_root_uri = 's3://drake-packages/drake'
download_root_uri = 'https://drake-packages.csail.mit.edu/drake'
archive_storage_class = 'STANDARD'
max_attempts = 3
backoff_delay = 15

supported_tracks = {'nightly', 'continuous', 'experimental'}


def age(days=0, hours=0, minutes=0):
    """
    Calculates an age in seconds from more convenient units.
    """
    return 60 * (minutes + (60 * (hours + (24 * days))))


def max_age(options, latest: bool):
    """
    Calculates the appropriate expiration (depending on the CI track and
    whether this is a 'latest' artifact) for an artifact.
    """
    def to_seconds(**kwargs):
        return int(datetime.timedelta(**kwargs).total_seconds())

    if options.nightly:
        return to_seconds(hours=18) if latest else to_seconds(days=45)
    else:
        return to_seconds(minutes=30) if latest else to_seconds(days=10)


def upload(path, name, expiration, options, noisy=False):
    """
    Attempts to upload a specific artifact to AWS S3. Tries up to
    `max_attempts` times before giving up. This is the internal helper function
    used by the more general wrappers.
    """
    command = [
        options.aws, 's3', 'cp',
        '--acl', 'public-read',
        '--storage-class', archive_storage_class,
        '--cache-control', f'max-age={expiration}',
        path, f'{aws_root_uri}/{options.track}/{name}']

    if noisy:
        print(f'-- Uploading {name} to AWS S3...', flush=True)

    print(command, file=sys.stderr, flush=True)

    attempt = 0
    while True:
        try:
            attempt += 1
            subprocess.check_call(command)
            break

        except Exception:
            if attempt < max_attempts:
                sleep(backoff_delay)
            else:
                raise

    if noisy:
        download_uri = f'{download_root_uri}/{options.track}/{name}'
        print(f'-- Upload complete: {download_uri}', flush=True)


def upload_checksum(path, name, expiration, options):
    """
    Computes the checksum of an artifact, creates a checksum file, and uploads
    the checksum file to AWS S3.
    """
    checksum = hashlib.sha512()

    with open(path, mode='rb') as f:
        while True:
            data = f.read(64 << 10)
            if not data:
                break
            checksum.update(data)

    with tempfile.NamedTemporaryFile(mode='w') as f:
        f.write(f'{checksum.hexdigest()}  {name}\n')
        f.flush()

        print(f'-- Uploading {name} checksum to AWS S3...', flush=True)
        upload(f.name, f'{name}.sha512', expiration, options)


def upload_artifacts(options):
    """
    Uploads an artifact (and checksums) to AWS S3. Depending on the CI track,
    also uploads a copy as 'latest'.
    """
    path = options.artifact
    name = os.path.basename(path)
    expiration = max_age(options, latest=False)

    upload(path, name, expiration, options, noisy=True)
    upload_checksum(path, name, expiration, options)

    if not options.experimental:
        # Names are expected too like like one of:
        #   drake-<version>-<stuff>
        #   drake-<date>-<git sha>-<stuff>
        #
        # A 'latest' artifact should preserve '<stuff>' unaltered, but replace
        # the version/data/sha with 'latest'. This regex matches the above and
        # allows us to extract the '<stuff>' portion of the name.
        m = re.match(r'^drake-[^-]+(-[0-9a-f]{40})?-(.*)$', name)
        if m is not None:
            residue = m.group(2)  # '<stuff>'
            name = f'drake-latest-{residue}'
            expiration = max_age(options, latest=True)

            upload(path, name, expiration, options, noisy=True)
            upload_checksum(path, name, expiration, options)
        else:
            print(f'Failed to transform version in artifact {name}; '
                  'no \'latest\' will be uploaded.', file=sys.stderr)


def main(args):
    parser = argparse.ArgumentParser()

    parser.add_argument(
        'artifact', type=str,
        help='Artifact to be uploaded')
    parser.add_argument(
        '--aws', type=str, default='aws',
        help='Path to AWS executable')
    parser.add_argument(
        '--track', type=str.lower, required=True, choices=supported_tracks,
        help='CI track of artifact')

    options = parser.parse_args(args)

    for t in supported_tracks:
        setattr(options, t, options.track == t)

    if not os.path.exists(options.artifact):
        parser.error(f'Artifact {options.artifact!r} does not exist')

    upload_artifacts(options)


if __name__ == '__main__':
    main(sys.argv[1:])
