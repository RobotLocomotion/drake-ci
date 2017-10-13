#!/bin/bash
set -euxo pipefail
export PATH="/usr/local/bin:$PATH"
mkdir -p build/install/share/doc/drake
unzip bazel-genfiles/drake/doc/sphinx.zip -d build/install/share/doc/drake
./drake/doc/doxygen.py
cp -r build/drake/doc/doxygen_cxx/html build/install/share/doc/drake/doxygen_cxx
echo drake.mit.edu > build/install/share/doc/drake/CNAME
touch build/install/share/doc/drake/.nojekyll
