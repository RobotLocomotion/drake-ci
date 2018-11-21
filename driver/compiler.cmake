# -*- mode: cmake -*-
# vi: set ft=cmake :

# Copyright (c) 2016, Massachusetts Institute of Technology.
# Copyright (c) 2016, Toyota Research Institute.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
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

# Select appropriate compiler version
set(DASHBOARD_GNU_COMPILER_SUFFIX "")
set(DASHBOARD_CLANG_COMPILER_SUFFIX "")
if(DASHBOARD_UNIX_DISTRIBUTION STREQUAL "Ubuntu")
  if(DASHBOARD_UNIX_DISTRIBUTION_VERSION VERSION_LESS 18.04)
    set(DASHBOARD_CLANG_COMPILER_SUFFIX "-6.0")
    # CC and CXX variables must be different between 16.04 and 18.04 so that
    # the environments differ for the purpose of remote caching.
    set(DASHBOARD_GNU_COMPILER_SUFFIX "-5")
  endif()
endif()

if(COMPILER STREQUAL "clang")
  set(ENV{CC} "clang${DASHBOARD_CLANG_COMPILER_SUFFIX}")
  set(ENV{CXX} "clang++${DASHBOARD_CLANG_COMPILER_SUFFIX}")
elseif(COMPILER STREQUAL "gcc")
  set(ENV{CC} "gcc${DASHBOARD_GNU_COMPILER_SUFFIX}")
  set(ENV{CXX} "g++${DASHBOARD_GNU_COMPILER_SUFFIX}")
else()
  fatal("unknown compiler '${COMPILER}'")
endif()
