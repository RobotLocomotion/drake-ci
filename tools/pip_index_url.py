"""Create an ``index.html`` suitable for use with ``pip --index-url``.

Scrape which nightly wheels are available (not in glacier storage) from drake's
nightly s3 bucket.  Create PEP 503 https://peps.python.org/pep-0503/ compliant
``index.html`` and uploaded it to the drake s3 bucket.

This script runs automatically every morning at 9:00am eastern so that the
nightly artifacts are complete.  The script can also be run manually to
regenerate as needed (e.g., nightly builds were failing and it needs to re-run
after they were fixed).

NOTE: to develop locally, you must have your ~/.aws/config and
~/.aws/credentials already configured for drake.
"""
from __future__ import annotations

import datetime
import io
import operator
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from textwrap import dedent

import boto3


@dataclass
class Wheel:
    s3_key: str
    yyyymmdd: str
    py_minor: int  # e.g. the 11 in "Python 3.11"
    sha512: str = None


def main() -> None:
    # Log in to s3.
    print("==> Logging in to s3 ...")
    s3 = boto3.resource("s3")
    bucket_name = "drake-packages"
    bucket = s3.Bucket(bucket_name)

    # Query the drake-packages bucket for drake/nightly/... wheel files from
    # the past 48 days that are not in Glacier storage. The files are named
    # like `drake-0.0.20230830-cp310-cp310-manylinux_2_31_x86_64.whl`.
    wheels: list[Wheel] = []
    print(f"==> Querying {bucket_name} objects ...")
    days_back = 48
    version_re = re.compile(r"^drake-0\.0\.([0-9]{8})-cp3([0-9]{1,2})-.*")
    for obj in bucket.objects.filter(Prefix="drake/nightly/"):
        if obj.storage_class != "STANDARD":
            continue
        if not obj.key.endswith(".whl"):
            continue
        if "drake-latest" in obj.key:
            continue
        # Parse the version numbers.
        match = version_re.match(Path(obj.key).name)
        assert match is not None, obj.key
        yyyymmdd, py_minor = match.groups()
        # Check whether the date is sufficiently new.
        date = datetime.date(year=int(yyyymmdd[:4]),
                             month=int(yyyymmdd[4:6]),
                             day=int(yyyymmdd[6:8]))
        if (datetime.date.today() - date).days <= days_back:
            wheels.append(Wheel(
                s3_key=obj.key,
                yyyymmdd=yyyymmdd,
                py_minor=int(py_minor),
            ))

    # Sort by newest.
    wheels.sort(key=operator.attrgetter("yyyymmdd", "py_minor"), reverse=True)

    # Download and parse the `*.sha512` checksum files. File format:
    # {sha512 hash}  {filename}
    for i, wheel in enumerate(wheels):
        sha_key = f"{wheel.s3_key}.sha512"
        print(f"  DOWNLOAD ({i+1}/{len(wheels)}): {sha_key}")
        sha_data = io.BytesIO()
        s3.Object(bucket_name, sha_key).download_fileobj(sha_data)
        wheel.sha512 = sha_data.getvalue().decode("utf-8").strip().split()[0]

    # Generate the index.html contents to upload.  See for reference:
    # - https://peps.python.org/pep-0503/#specification
    # - https://pypi.org/simple/drake/
    # - view-source:https://pypi.org/simple/drake/
    print(f"==> Generating index.html.")
    html = io.StringIO()
    html.write("""\
<!DOCTYPE html>
<html lang="en-US>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<meta charset="utf-8"/>
<title>Drake Nightly Python Artifacts</title>
<meta name="description" content="Binary artifacts for Drake"/>
</head>
<body>
<h1>Drake Nightly Python Artifacts</h1>
""")
    wheel_files_url_base = ""
    for wheel in wheels:
        server = "drake-packages.csail.mit.edu"
        s3_key, sha512, py_minor = (wheel.s3_key, wheel.sha512, wheel.py_minor)
        html.write(
            f'<a href="https://{server}/{s3_key}#sha512={sha512}" '
            f'data-requires-python="&gt;=3.{py_minor},&lt;3.{py_minor+1}">'
            f'{Path(s3_key).name}</a><br/>\n')
    html.write("</body>\n</html>\n")

    print(html.getvalue())
    raise NotImplementedError()

    # Upload the index.html to the s3 bucket.
    s3_key = "whl/nightly/drake/index.html"
    print(f"==> Uploading to s3://{bucket_name}/{s3_key}.")
    s3.meta.client.upload_file(
        str(html_path),
        bucket_name,
        s3_key,
        ExtraArgs={
            # The Max-Age for browser caches (among other tools).  We desire it to
            # expire fairly quickly, the defaul tis 24 hours but 30 minutes will
            # force tools to reload the data more quickly.
            "CacheControl": "max-age=1800",  # 30 minutes in seconds
            # Make sure it is available as an HTML document, otherwise browsers
            # will just download the file and pip cannot use it.
            "ContentType": "text/html",  # Default is binary/octet-stream
            "StorageClass": "STANDARD",
            "ACL": "public-read",
        },
    )

    print("==> DONE!")


if __name__ == "__main__":
    main()
