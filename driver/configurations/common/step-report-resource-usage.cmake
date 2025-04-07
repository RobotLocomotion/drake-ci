# -*- mode: cmake; -*-
# vi: set ft=cmake:

# BSD 3-Clause License
#
# Copyright (c) 2018, Massachusetts Institute of Technology.
# Copyright (c) 2018, Toyota Research Institute.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
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
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Disk usage

execute_process(COMMAND df -h "${DASHBOARD_TEMP_DIR}"
  OUTPUT_VARIABLE dashboard_temp_dir_usage
  ERROR_QUIET
  OUTPUT_STRIP_TRAILING_WHITESPACE)

notice("Disk usage for ${DASHBOARD_TEMP_DIR}:\n ${dashboard_temp_dir_usage}")

if(NOT DASHBOARD_TEMP_DIR STREQUAL "/tmp")
  execute_process(COMMAND df -h "/tmp"
    OUTPUT_VARIABLE tmp_usage
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE)

  notice("Disk usage for /tmp:\n ${tmp_usage}")
endif()

# CPU and memory usage (overall and by process)

if(APPLE)
  execute_process(COMMAND top -l 1 -s 0 | grep PhysMem
    OUTPUT_VARIABLE dashboard_mem_usage
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE)
else()
  # macOS doesn't have free...
  execute_process(COMMAND free -m
    OUTPUT_VARIABLE dashboard_mem_usage
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE)
endif()

# This command has been carefully constructed to contain only options
# supported on both Ubuntu and macOS.
# `ps` differs slightly on the two systems for historical reasons.
execute_process(COMMAND ps -o pid,user,%cpu,%mem,comm -ax | sort -b -k4 -r | head -11
  OUTPUT_VARIABLE dashboard_mem_proc
  ERROR_QUIET
  OUTPUT_STRIP_TRAILING_WHITESPACE)

notice("Memory usage:\n ${dashboard_mem_usage}")
notice("Processes using most memory:\n ${dashboard_mem_proc}")
