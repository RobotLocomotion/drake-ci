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

# Get distribution information
if(APPLE)
  set(DASHBOARD_UNIX_DISTRIBUTION "Apple")
  # TODO version
elseif(EXISTS "/etc/os-release")
  file(READ "/etc/os-release" DISTRIBUTION_INFO)
  if(DISTRIBUTION_INFO MATCHES "(^|\n)NAME=\"?([^\n\"]+)\"?(\n|\$)")
    set(DASHBOARD_UNIX_DISTRIBUTION "${CMAKE_MATCH_2}")
  endif()
  if(DISTRIBUTION_INFO MATCHES "(^|\n)VERSION=\"?([0-9]+([.][0-9]+)?)")
    set(DASHBOARD_UNIX_DISTRIBUTION_VERSION "${CMAKE_MATCH_2}")
  endif()
  if(NOT DEFINED DASHBOARD_UNIX_DISTRIBUTION OR
     NOT DEFINED DASHBOARD_UNIX_DISTRIBUTION_VERSION)
    fatal("unable to determine platform distribution information")
  endif()
else()
  fatal("unable to determine platform distribution information")
endif()

if(COVERAGE AND NOT APPLE)
  prepend_path(PATH
    /opt/kcov/35/bin
    /opt/kcov/34/bin)
endif()

# Set (non-Apple) paths for MATLAB
if(MATLAB AND NOT APPLE)
  prepend_path(PATH /usr/local/MATLAB/R2017a/bin)
endif()
