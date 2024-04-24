# -*- mode: cmake; -*-
# vi: set ft=cmake:

# BSD 3-Clause License
#
# Copyright (c) 2020, Massachusetts Institute of Technology.
# Copyright (c) 2020, Toyota Research Institute.
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

set(DASHBOARD_CC_CACHE_VERSION)
set(DASHBOARD_GFORTRAN_CACHE_VERSION)
set(DASHBOARD_JAVA_CACHE_VERSION)
set(DASHBOARD_OS_CACHE_NAME)
set(DASHBOARD_OS_CACHE_VERSION)
set(DASHBOARD_PYTHON_CACHE_VERSION)
set(DASHBOARD_REMOTE_CACHE_KEY)

if(REMOTE_CACHE)
  mktemp(DASHBOARD_FILE_DOWNLOAD_TEMP file_download_XXXXXXXX
    "temporary download file"
  )
  list(APPEND DASHBOARD_TEMPORARY_FILES DASHBOARD_FILE_DOWNLOAD_TEMP)

  # NOTE: is there a new cache server being added (or an ip address changing)?
  # In addition to updating `DASHBOARD_REMOTE_CACHE` below, you must update:
  #
  # 1. drake-ci/cache_server/README.md heading section enumerating the servers.
  # 2. drake-ci/cache_server/health_check.bash section enumerating Linux vs
  #    Darwin ip addresses.
  if(APPLE)
    set(DASHBOARD_REMOTE_CACHE "http://10.221.188.9")
  else()
    set(DASHBOARD_REMOTE_CACHE "http://172.31.25.87")
  endif()
  message(STATUS
      "Testing download of remote cache server: '${DASHBOARD_REMOTE_CACHE}'")
  file(DOWNLOAD "${DASHBOARD_REMOTE_CACHE}" "${DASHBOARD_FILE_DOWNLOAD_TEMP}"
    STATUS DASHBOARD_DOWNLOAD_STATUS
    LOG DASHBOARD_DOWNLOAD_LOG
  )
  list(GET DASHBOARD_DOWNLOAD_STATUS 0 DASHBOARD_DOWNLOAD_STATUS_0)

  if(NOT DASHBOARD_DOWNLOAD_STATUS_0 EQUAL 0)
    message(WARNING
      "*** Disabling remote cache because could NOT contact remote cache server"
      "\n${DASHBOARD_DOWNLOAD_LOG}"
    )
    set(REMOTE_CACHE OFF)
  endif()
endif()

if(REMOTE_CACHE AND NOT APPLE)
  find_program(DPKG_QUERY_EXECUTABLE NAMES "dpkg-query"
    NO_CMAKE_PATH
    NO_CMAKE_ENVIRONMENT_PATH
    NO_CMAKE_SYSTEM_PATH
  )
  if(NOT DPKG_QUERY_EXECUTABLE)
    message(WARNING
      "*** Disabling remote cache because could NOT find dpkg-query when computing remote cache key"
  )
    set(REMOTE_CACHE OFF)
  endif()
endif()

if(REMOTE_CACHE)
  find_program(CC_EXECUTABLE NAMES "${DASHBOARD_CC_COMMAND}"
    NO_CMAKE_PATH
    NO_CMAKE_ENVIRONMENT_PATH
    NO_CMAKE_SYSTEM_PATH
  )
  if(NOT CC_EXECUTABLE)
    message(WARNING
      "*** Disabling remote cache because could NOT find ${COMPILER} when computing remote cache key"
    )
    set(REMOTE_CACHE OFF)
  endif()
endif()

if(REMOTE_CACHE AND CC_EXECUTABLE)
  get_filename_component(CC_EXECUTABLE "${CC_EXECUTABLE}" REALPATH)
  if(DPKG_QUERY_EXECUTABLE)
    separate_arguments(DPKG_QUERY_SEARCH_CC_ARGS_LIST
      UNIX_COMMAND "-S ${CC_EXECUTABLE}"
    )
    execute_process(
      COMMAND ${DPKG_QUERY_EXECUTABLE} ${DPKG_QUERY_SEARCH_CC_ARGS_LIST}
      RESULT_VARIABLE DPKG_QUERY_SEARCH_CC_RESULT_VARIABLE
      OUTPUT_VARIABLE DPKG_QUERY_SEARCH_CC_OUTPUT_VARIABLE
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(DPKG_QUERY_SEARCH_CC_RESULT_VARIABLE EQUAL 0)
      string(REPLACE ":" ";" DPKG_QUERY_SEARCH_CC_OUTPUT_LIST
        "${DPKG_QUERY_SEARCH_CC_OUTPUT_VARIABLE}"
      )
      list(GET DPKG_QUERY_SEARCH_CC_OUTPUT_LIST 0 DASHBOARD_CC_PACKAGE_NAME)
      separate_arguments(DPKG_QUERY_SHOW_CC_ARGS_LIST
        UNIX_COMMAND "-f \${Version} -W ${DASHBOARD_CC_PACKAGE_NAME}"
      )
      execute_process(
        COMMAND ${DPKG_QUERY_EXECUTABLE} ${DPKG_QUERY_SHOW_CC_ARGS_LIST}
        RESULT_VARIABLE DPKG_QUERY_SHOW_CC_RESULT_VARIABLE
        OUTPUT_VARIABLE DPKG_QUERY_SHOW_CC_OUTPUT_VARIABLE
        OUTPUT_STRIP_TRAILING_WHITESPACE
      )
      if(DPKG_QUERY_SHOW_CC_RESULT_VARIABLE EQUAL 0)
        set(DASHBOARD_CC_CACHE_VERSION
          "${DPKG_QUERY_SHOW_CC_OUTPUT_VARIABLE}"
        )
      else()
        message(WARNING
          "*** Disabling remote cache because could NOT determine ${COMPILER} version using dpkg-query when computing remote cache key"
        )
        set(REMOTE_CACHE OFF)
      endif()
    else()
      message(WARNING
        "*** Disabling remote cache because could NOT determine ${COMPILER} package name using dpkg-query when computing remote cache key"
      )
      set(REMOTE_CACHE OFF)
    endif()
  else()
    separate_arguments(DASHBOARD_CC_VERSION_ARGS_LIST
      UNIX_COMMAND "--version"
    )
    execute_process(
      COMMAND ${CC_EXECUTABLE} ${DASHBOARD_CC_VERSION_ARGS_LIST}
      RESULT_VARIABLE DASHBOARD_CC_VERSION_RESULT_VARIABLE
      OUTPUT_VARIABLE DASHBOARD_CC_VERSION_OUTPUT_VARIABLE
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(DASHBOARD_CC_VERSION_RESULT_VARIABLE EQUAL 0 AND
       DASHBOARD_CC_VERSION_OUTPUT_VARIABLE MATCHES
       "^Apple clang version ([0-9]+[.][0-9]+[.][0-9]+)"
    )
      set(DASHBOARD_CC_CACHE_VERSION "${CMAKE_MATCH_1}")
    else()
      message(WARNING
        "*** Disabling remote cache because could NOT determine Apple clang version when computing remote cache key"
      )
      set(REMOTE_CACHE OFF)
    endif()
  endif()
endif()

if(REMOTE_CACHE)
  find_program(GFORTRAN_EXECUTABLE NAMES "gfortran"
    NO_CMAKE_PATH
    NO_CMAKE_ENVIRONMENT_PATH
    NO_CMAKE_SYSTEM_PATH
  )
  if(NOT GFORTRAN_EXECUTABLE)
    message(WARNING
      "*** Disabling remote cache because could NOT find gfortran when computing remote cache key"
    )
    set(REMOTE_CACHE OFF)
  endif()
endif()


if(REMOTE_CACHE AND GFORTRAN_EXECUTABLE)
  get_filename_component(GFORTRAN_EXECUTABLE
    "${GFORTRAN_EXECUTABLE}" REALPATH
  )
  if(DPKG_QUERY_EXECUTABLE)
    separate_arguments(DPKG_QUERY_SEARCH_GFORTRAN_ARGS_LIST
      UNIX_COMMAND "-S ${GFORTRAN_EXECUTABLE}"
    )
    execute_process(
      COMMAND ${DPKG_QUERY_EXECUTABLE} ${DPKG_QUERY_SEARCH_GFORTRAN_ARGS_LIST}
      RESULT_VARIABLE DPKG_QUERY_SEARCH_GFORTRAN_RESULT_VARIABLE
      OUTPUT_VARIABLE DPKG_QUERY_SEARCH_GFORTRAN_OUTPUT_VARIABLE
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(DPKG_QUERY_SEARCH_GFORTRAN_RESULT_VARIABLE EQUAL 0)
      string(REPLACE ":" ";" DPKG_QUERY_SEARCH_GFORTRAN_OUTPUT_LIST
        "${DPKG_QUERY_SEARCH_GFORTRAN_OUTPUT_VARIABLE}"
      )
      list(GET DPKG_QUERY_SEARCH_GFORTRAN_OUTPUT_LIST 0
        DASHBOARD_GFORTRAN_PACKAGE_NAME
      )
      separate_arguments(DPKG_QUERY_SHOW_GFORTRAN_ARGS_LIST
        UNIX_COMMAND "-f \${Version} -W ${DASHBOARD_GFORTRAN_PACKAGE_NAME}"
      )
      execute_process(
        COMMAND ${DPKG_QUERY_EXECUTABLE} ${DPKG_QUERY_SHOW_GFORTRAN_ARGS_LIST}
        RESULT_VARIABLE DPKG_QUERY_SHOW_GFORTRAN_RESULT_VARIABLE
        OUTPUT_VARIABLE DPKG_QUERY_SHOW_GFORTRAN_OUTPUT_VARIABLE
        OUTPUT_STRIP_TRAILING_WHITESPACE
      )
      if(DPKG_QUERY_SHOW_GFORTRAN_RESULT_VARIABLE EQUAL 0)
        set(DASHBOARD_GFORTRAN_CACHE_VERSION
          "${DPKG_QUERY_SHOW_GFORTRAN_OUTPUT_VARIABLE}"
        )
      else()
        message(WARNING
          "*** Disabling remote cache because could NOT determine gfortran version using dpkg-query when computing remote cache key"
        )
        set(REMOTE_CACHE OFF)
      endif()
    else()
      message(WARNING
        "*** Disabling remote cache because could NOT determine gfortran package name using dpkg-query when computing remote cache key"
      )
      set(REMOTE_CACHE OFF)
    endif()
  else()
    separate_arguments(DASHBOARD_GFORTRAN_VERSION_ARGS_LIST
      UNIX_COMMAND "--version"
    )
    execute_process(
      COMMAND ${GFORTRAN_EXECUTABLE} ${DASHBOARD_GFORTRAN_VERSION_ARGS_LIST}
      RESULT_VARIABLE DASHBOARD_GFORTRAN_VERSION_RESULT_VARIABLE
      OUTPUT_VARIABLE DASHBOARD_GFORTRAN_VERSION_OUTPUT_VARIABLE
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(DASHBOARD_GFORTRAN_VERSION_RESULT_VARIABLE EQUAL 0 AND
       DASHBOARD_GFORTRAN_VERSION_OUTPUT_VARIABLE MATCHES
       "^GNU Fortran \\(.*\\) ([0-9]+[.][0-9]+[.][0-9]+)"
    )
      set(DASHBOARD_GFORTRAN_CACHE_VERSION "${CMAKE_MATCH_1}")
    else()
      message(WARNING
        "*** Disabling remote cache because could NOT determine gfortran version when computing remote cache key"
      )
      set(REMOTE_CACHE OFF)
    endif()
  endif()
endif()


if(REMOTE_CACHE)
  find_program(Java_JAVA_EXECUTABLE NAMES "java"
    NO_CMAKE_PATH
    NO_CMAKE_ENVIRONMENT_PATH
    NO_CMAKE_SYSTEM_PATH
  )
  if(NOT Java_JAVA_EXECUTABLE)
    message(WARNING
      "*** Disabling remote cache because could NOT find java when computing remote cache key"
    )
    set(REMOTE_CACHE OFF)
  endif()
endif()


if(REMOTE_CACHE AND Java_JAVA_EXECUTABLE)
  get_filename_component(Java_JAVA_EXECUTABLE
    "${Java_JAVA_EXECUTABLE}" REALPATH
  )
  if(DPKG_QUERY_EXECUTABLE)
    separate_arguments(DPKG_QUERY_SEARCH_JAVA_ARGS_LIST
      UNIX_COMMAND "-S ${Java_JAVA_EXECUTABLE}"
    )
    execute_process(
      COMMAND ${DPKG_QUERY_EXECUTABLE} ${DPKG_QUERY_SEARCH_JAVA_ARGS_LIST}
      RESULT_VARIABLE DPKG_QUERY_SEARCH_JAVA_RESULT_VARIABLE
      OUTPUT_VARIABLE DPKG_QUERY_SEARCH_JAVA_OUTPUT_VARIABLE
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(DPKG_QUERY_SEARCH_JAVA_RESULT_VARIABLE EQUAL 0)
      string(REPLACE ":" ";" DPKG_QUERY_SEARCH_JAVA_OUTPUT_LIST
        "${DPKG_QUERY_SEARCH_JAVA_OUTPUT_VARIABLE}"
      )
      list(GET DPKG_QUERY_SEARCH_JAVA_OUTPUT_LIST 0
        DASHBOARD_JAVA_PACKAGE_NAME
      )
      separate_arguments(DPKG_QUERY_SHOW_JAVA_ARGS_LIST
        UNIX_COMMAND "-f \${Version} -W ${DASHBOARD_JAVA_PACKAGE_NAME}"
      )
      execute_process(
        COMMAND ${DPKG_QUERY_EXECUTABLE} ${DPKG_QUERY_SHOW_JAVA_ARGS_LIST}
        RESULT_VARIABLE DPKG_QUERY_SHOW_JAVA_RESULT_VARIABLE
        OUTPUT_VARIABLE DPKG_QUERY_SHOW_JAVA_OUTPUT_VARIABLE
        OUTPUT_STRIP_TRAILING_WHITESPACE
      )
      if(DPKG_QUERY_SHOW_JAVA_RESULT_VARIABLE EQUAL 0)
        set(DASHBOARD_JAVA_CACHE_VERSION
          "${DPKG_QUERY_SHOW_JAVA_OUTPUT_VARIABLE}"
        )
      else()
        message(WARNING
          "*** Disabling remote cache because could NOT determine Java version using dpkg-query when computing remote cache key"
        )
        set(REMOTE_CACHE OFF)
      endif()
    else()
      message(WARNING
        "*** Disabling remote cache because could NOT determine Java package name using dpkg-query when computing remote cache key"
      )
      set(REMOTE_CACHE OFF)
    endif()
  else()
    separate_arguments(DASHBOARD_JAVA_VERSION_ARGS_LIST
      UNIX_COMMAND "-version"
    )
    execute_process(
      COMMAND ${Java_JAVA_EXECUTABLE} ${DASHBOARD_JAVA_VERSION_ARGS_LIST}
      RESULT_VARIABLE DASHBOARD_JAVA_VERSION_RESULT_VARIABLE
      ERROR_VARIABLE DASHBOARD_JAVA_VERSION_ERROR_VARIABLE
      ERROR_STRIP_TRAILING_WHITESPACE
    )
    message(STATUS "${DASHBOARD_JAVA_VERSION_ERROR_VARIABLE}")
    if(DASHBOARD_JAVA_VERSION_RESULT_VARIABLE EQUAL 0 AND
       DASHBOARD_JAVA_VERSION_ERROR_VARIABLE MATCHES
       "^(java|openjdk) version \"([0-9\.]+)\""
    )
      set(DASHBOARD_JAVA_CACHE_VERSION "${CMAKE_MATCH_2}")
    else()
      message(WARNING
        "*** Disabling remote cache because could NOT determine Java version when computing remote cache key"
      )
      set(REMOTE_CACHE OFF)
    endif()
  endif()
endif()


if(APPLE)
  if(REMOTE_CACHE)
    set(DASHBOARD_OS_CACHE_NAME "macos")
    find_program(SW_VERS_EXECUTABLE NAMES "sw_vers"
      NO_CMAKE_PATH
      NO_CMAKE_ENVIRONMENT_PATH
      NO_CMAKE_SYSTEM_PATH
    )
    if(NOT SW_VERS_EXECUTABLE)
      message(WARNING
        "*** Disabling remote cache because could NOT find sw_vers when computing remote cache key"
      )
      set(REMOTE_CACHE OFF)
    endif()
  endif()

  if(REMOTE_CACHE AND SW_VERS_EXECUTABLE)
    separate_arguments(DASHBOARD_SW_VERS_PRODUCT_VERSION_ARGS_LIST
      UNIX_COMMAND "-productVersion"
    )
    execute_process(
      COMMAND ${SW_VERS_EXECUTABLE} ${DASHBOARD_SW_VERS_PRODUCT_VERSION_ARGS_LIST}
      RESULT_VARIABLE DASHBOARD_SW_VERS_PRODUCT_VERSION_RESULT_VARIABLE
      OUTPUT_VARIABLE DASHBOARD_SW_VERS_PRODUCT_VERSION_OUTPUT_VARIABLE
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(DASHBOARD_SW_VERS_PRODUCT_VERSION_RESULT_VARIABLE EQUAL 0)
      set(DASHBOARD_OS_CACHE_VERSION "${DASHBOARD_SW_VERS_PRODUCT_VERSION_OUTPUT_VARIABLE}")
    else()
      message(WARNING
        "*** Disabling remote cache because could NOT determine macOS version using sw_vers when computing remote cache key"
      )
      set(REMOTE_CACHE OFF)
    endif()
  endif()
else()
  if(REMOTE_CACHE)
    set(DASHBOARD_OS_CACHE_NAME "ubuntu")
    find_program(LSB_RELEASE_EXECUTABLE NAMES "lsb_release"
      NO_CMAKE_PATH
      NO_CMAKE_ENVIRONMENT_PATH
      NO_CMAKE_SYSTEM_PATH
    )
    if(NOT LSB_RELEASE_EXECUTABLE)
      message(WARNING
        "*** Disabling remote cache because could NOT find lsb_release when computing remote cache key"
      )
      set(REMOTE_CACHE OFF)
    endif()
  endif()

  if(REMOTE_CACHE AND LSB_RELEASE_EXECUTABLE)
    separate_arguments(DASHBOARD_LSB_RELEASE_DESCRIPTION_ARGS_LIST
      UNIX_COMMAND "-ds"
    )
    execute_process(
      COMMAND ${LSB_RELEASE_EXECUTABLE} ${DASHBOARD_LSB_RELEASE_DESCRIPTION_ARGS_LIST}
      RESULT_VARIABLE DASHBOARD_LSB_RELEASE_DESCRIPTION_RESULT_VARIABLE
      OUTPUT_VARIABLE DASHBOARD_LSB_RELEASE_DESCRIPTION_OUTPUT_VARIABLE
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    # NOTE: `lsb_release -ds` may report differing amounts of version numbers,
    # e.g., `Ubuntu 20.04.4 LTS` or `Ubuntu 22.04 LTS`.
    if(DASHBOARD_LSB_RELEASE_DESCRIPTION_RESULT_VARIABLE EQUAL 0 AND
       DASHBOARD_LSB_RELEASE_DESCRIPTION_OUTPUT_VARIABLE MATCHES
       "^Ubuntu ([0-9]+([.][0-9]+)+) LTS$"
    )
      set(DASHBOARD_OS_CACHE_VERSION "${CMAKE_MATCH_1}")
    else()
      message(WARNING
        "*** Disabling remote cache because could NOT determine Ubuntu version using lsb_release when computing remote cache key"
      )
      set(REMOTE_CACHE OFF)
    endif()
  endif()
endif()

if(REMOTE_CACHE)
  get_filename_component(PYTHON_EXECUTABLE "${DASHBOARD_PYTHON_COMMAND}" REALPATH)
  if(DPKG_QUERY_EXECUTABLE)
    separate_arguments(DPKG_QUERY_SEARCH_PYTHON_ARGS_LIST
      UNIX_COMMAND "-S ${PYTHON_EXECUTABLE}"
    )
    execute_process(
      COMMAND ${DPKG_QUERY_EXECUTABLE} ${DPKG_QUERY_SEARCH_PYTHON_ARGS_LIST}
      RESULT_VARIABLE DPKG_QUERY_SEARCH_PYTHON_RESULT_VARIABLE
      OUTPUT_VARIABLE DPKG_QUERY_SEARCH_PYTHON_OUTPUT_VARIABLE
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(DPKG_QUERY_SEARCH_PYTHON_RESULT_VARIABLE EQUAL 0)
      string(REPLACE ":" ";" DPKG_QUERY_SEARCH_PYTHON_OUTPUT_LIST
        "${DPKG_QUERY_SEARCH_PYTHON_OUTPUT_VARIABLE}"
      )
      list(GET DPKG_QUERY_SEARCH_PYTHON_OUTPUT_LIST 0
        DASHBOARD_PYTHON_PACKAGE_NAME
      )
      separate_arguments(DPKG_QUERY_SHOW_PYTHON_ARGS_LIST
        UNIX_COMMAND "-f \${Version} -W ${DASHBOARD_PYTHON_PACKAGE_NAME}"
      )
      execute_process(
        COMMAND ${DPKG_QUERY_EXECUTABLE} ${DPKG_QUERY_SHOW_PYTHON_ARGS_LIST}
        RESULT_VARIABLE DPKG_QUERY_SHOW_PYTHON_RESULT_VARIABLE
        OUTPUT_VARIABLE DPKG_QUERY_SHOW_PYTHON_OUTPUT_VARIABLE
        OUTPUT_STRIP_TRAILING_WHITESPACE
      )
      if(DPKG_QUERY_SHOW_PYTHON_RESULT_VARIABLE EQUAL 0)
        set(DASHBOARD_PYTHON_CACHE_VERSION
          "${DPKG_QUERY_SHOW_PYTHON_OUTPUT_VARIABLE}"
        )
      else()
        message(WARNING
          "*** Disabling remote cache because could NOT determine Python version using dpkg-query when computing remote cache key"
        )
        set(REMOTE_CACHE OFF)
      endif()
    else()
      message(WARNING
        "*** Disabling remote cache because could NOT determine Python package name using dpkg-query when computing remote cache key"
      )
      set(REMOTE_CACHE OFF)
    endif()
  else()
    separate_arguments(DASHBOARD_PYTHON_VERSION_ARGS_LIST UNIX_COMMAND "-V")
    execute_process(
      COMMAND ${DASHBOARD_PYTHON_COMMAND} ${DASHBOARD_PYTHON_VERSION_ARGS_LIST}
      RESULT_VARIABLE DASHBOARD_PYTHON_VERSION_RESULT_VARIABLE
      OUTPUT_VARIABLE DASHBOARD_PYTHON_VERSION_OUTPUT_VARIABLE
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(DASHBOARD_PYTHON_VERSION_RESULT_VARIABLE EQUAL 0 AND
       DASHBOARD_PYTHON_VERSION_OUTPUT_VARIABLE MATCHES
       "^Python ([0-9]+[.][0-9]+[.][0-9]+)$"
    )
      set(DASHBOARD_PYTHON_CACHE_VERSION "${CMAKE_MATCH_1}")
    else()
      message(WARNING
        "*** Disabling remote cache because could NOT determine Python version when computing remote cache key"
      )
      set(REMOTE_CACHE OFF)
    endif()
  endif()
endif()

if(REMOTE_CACHE)
  if(DASHBOARD_CC_CACHE_VERSION AND
     DASHBOARD_GFORTRAN_CACHE_VERSION AND
     DASHBOARD_JAVA_CACHE_VERSION AND
     DASHBOARD_OS_CACHE_NAME AND
     DASHBOARD_OS_CACHE_VERSION AND
     DASHBOARD_PYTHON_CACHE_VERSION
  )
    set(DASHBOARD_REMOTE_CACHE_KEY_VERSION "v7")
    set(DASHBOARD_CACHE_VERSIONS
      "${COMPILER}:${DASHBOARD_CC_CACHE_VERSION}"
      "gfortran:${DASHBOARD_GFORTRAN_CACHE_VERSION}"
      "java:${DASHBOARD_JAVA_CACHE_VERSION}"
      "${DASHBOARD_OS_CACHE_NAME}:${DASHBOARD_OS_CACHE_VERSION}"
      "python:${DASHBOARD_PYTHON_CACHE_VERSION}"
    )
    list(SORT DASHBOARD_CACHE_VERSIONS)
    list(JOIN DASHBOARD_CACHE_VERSIONS "," DASHBOARD_CACHE_VERSIONS_STRING)
    string(SHA256 DASHBOARD_REMOTE_CACHE_KEY
      "${DASHBOARD_CACHE_VERSIONS_STRING}"
    )
    set(DASHBOARD_REMOTE_CACHE
      "${DASHBOARD_REMOTE_CACHE}/${DASHBOARD_REMOTE_CACHE_KEY_VERSION}/${DASHBOARD_REMOTE_CACHE_KEY}"
    )
  else()
    message(WARNING
      "*** Disabling remote cache because could NOT compute remote cache key"
    )
    set(REMOTE_CACHE OFF)
  endif()
endif()
