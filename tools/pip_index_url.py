"""Create an ``index.html`` suitable for use with ``pip --index-url``.

Scrape which nightly wheels are available (not in glacier storage) from drake's nightly
s3 bucket.  Create PEP 503 https://peps.python.org/pep-0503/ compliant ``index.html``
and uploaded it to the drake s3 bucket.

This script runs automatically every morning at 9:00am eastern so that the nightly
artifacts are complete.  The script can also be run manually to regenerate as needed
(e.g., nightly builds were failing and it needs to re-run after they were fixed).

NOTE: to develop locally, you must have your ~/.aws/config and ~/.aws/credentials
already configured for drake.
"""
from __future__ import annotations

import re
import sys
import tempfile
from pathlib import Path
from textwrap import dedent

import boto3


def main() -> None:
    # Accumulate any errors and display at the end.
    error_messages: list[str] = []

    # Keys: wheel basename, Values: sha512 hash
    drake_nightly_wheels: dict[str, str] = {}

    # Login to s3 and query the drake-packages bucket for wheel files not already
    # transitioned to glacier storage.  Do not include any "drake-latest" wheels such
    # as `drake-latest-cp310-cp310-manylinux_2_31_x86_64.whl`, we only want to include
    # actual versioned wheel files.
    #
    # Since the sha512 files are uploaded separately, we will download each of those
    # in order to include the expected sha512 hash of the wheel file.
    temp_directory = tempfile.TemporaryDirectory(prefix="drake_pip_index_url_")
    temp_directory_path = Path(temp_directory.name)

    # It is helpful to include logging to the console so the user understand the
    # script is still working on things.
    print("==> Logging into s3.")
    s3 = boto3.resource("s3")
    bucket_name = "drake-packages"
    drake_nightly_bucket = s3.Bucket("drake-packages")
    print(f"==> Querying {bucket_name} objects.")
    for obj in drake_nightly_bucket.objects.all():
        if (
            obj.storage_class == "STANDARD"
            and obj.key.startswith("drake/nightly")
            and obj.key.endswith(".whl")
        ):
            # Overwrite drake/nightly/<some path>.whl with just <some path>.whl
            obj_basename = Path(obj.key).name
            if not obj_basename.startswith("drake-latest"):
                print(f"- FOUND: {obj.key}")
                sha512_name = f"{obj.key}.sha512"
                print(f"  DOWNLOAD: {sha512_name}")
                try:
                    sha512_obj = s3.Object(
                        bucket_name=bucket_name,
                        key=sha512_name,
                    )
                    # NOTE: use the basename of `sha512_name` to avoid needing to
                    # create drake/nightly/ subdirectories.
                    sha512_dest = temp_directory_path / Path(sha512_name).name
                    sha512_obj.download_file(Filename=str(sha512_dest))
                    # File format:
                    # {sha512 hash}  {filename}
                    with open(sha512_dest, "r") as sha512_f:
                        sha512_hash = sha512_f.read().strip().split()[0]
                    print(f"  SHA512: {sha512_hash}")

                    drake_nightly_wheels[obj_basename] = sha512_hash
                except Exception as e:
                    error_messages.append(
                        f"Could not download {sha512_name} from {bucket_name}: {e}"
                    )

    # Generate the index.html contents to upload.  See for reference:
    # - https://peps.python.org/pep-0503/#specification
    # - https://pypi.org/simple/drake/
    # - view-source:https://pypi.org/simple/drake/
    index_html_path = temp_directory_path / "index.html"
    print(f"==> Generating {index_html_path}.")
    with open(index_html_path, "w") as index_html:
        index_html.write(
            dedent(
                """
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
        """
            )
        )
        version_re = re.compile(
            r"^drake-[0-9\.]+-cp(?P<min>[0-9]+)-cp(?P<max>[0-9+]).*$"
        )
        base_url = "https://drake-packages.csail.mit.edu/drake/nightly"
        for filename, sha512_hash in drake_nightly_wheels.items():
            # Determine what the data-requires-python minimum version is.
            m = version_re.match(filename)
            if m is None:
                error_messages.append(
                    f"Could not match '{filename}' with {version_re}."
                )
                continue

            # min_python will be e.g., '36' or '311', we need '3.6' or '3.11'.
            min_python = m.group("min")
            if len(min_python) < 2:
                error_messages.append(
                    f"Unknown min_python version '{min_python}' for {filename}, must "
                    "be at least length two."
                )
                continue

            min_python = f"{min_python[0]}.{min_python[1:]}"
            href = f"{base_url}/{filename}#sha512={sha512_hash}"
            data_requires_python = f'data-requires-python="&gt;={min_python}"'
            index_html.write(
                f'    <a href="{href}" {data_requires_python}>{filename}</a><br />\n'
            )

        index_html.write(
            dedent(
                """\
              </body>
            </html>
        """
            )
        )

    # Upload the index.html to the s3 bucket.
    try:
        s3_index_html_dest = "drake/nightly/index.html"
        print(f"==> Uploading {index_html_path} to {s3_index_html_dest}.")
        s3.meta.client.upload_file(
            str(index_html_path),
            bucket_name,
            s3_index_html_dest,
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
    except Exception as e:
        error_messages.append(f"Unable to upload {index_html_path}: {e}")

    # Display any errors and fail the CI build to let buildcops know.
    if error_messages:
        for em in error_messages:
            sys.stderr.write(f"[X] {em}\n")
        sys.stderr.write(f"NOT deleting {temp_directory_path}, remove manually!\n")
        sys.exit(1)

    # Remove all the files we just downloaded / created.
    try:
        temp_directory.cleanup()
    except Exception as e:
        sys.stderr.write(f"Error deleting {temp_directory_path}: {e}\n")
        sys.exit(1)

    print("==> DONE!")


if __name__ == "__main__":
    main()
