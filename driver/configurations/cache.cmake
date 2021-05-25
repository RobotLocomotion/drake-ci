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

set(DASHBOARD_CC_PACKAGE_VERSION)
set(DASHBOARD_GFORTRAN_PACKAGE_VERSION)
set(DASHBOARD_JAVA_PACKAGE_VERSION)
set(DASHBOARD_PYTHON_PACKAGE_VERSION)
set(DASHBOARD_REMOTE_CACHE_KEY)

if(REMOTE_CACHE)
  mktemp(DASHBOARD_FILE_DOWNLOAD_TEMP file_download_XXXXXXXX
    "temporary download file"
  )
  list(APPEND DASHBOARD_TEMPORARY_FILES DASHBOARD_FILE_DOWNLOAD_TEMP)

  if(APPLE)
    set(DASHBOARD_REMOTE_CACHE "http://207.254.3.134")
  else()
    set(DASHBOARD_REMOTE_CACHE "http://172.31.20.109")
  endif()
  file(DOWNLOAD "${DASHBOARD_REMOTE_CACHE}" "${DASHBOARD_FILE_DOWNLOAD_TEMP}"
    STATUS DASHBOARD_DOWNLOAD_STATUS
  )
  list(GET DASHBOARD_DOWNLOAD_STATUS 0 DASHBOARD_DOWNLOAD_STATUS_0)

  if(NOT DASHBOARD_DOWNLOAD_STATUS_0 EQUAL 0)
    message(WARNING
      "*** Disabling remote cache because could NOT contact remote cache server"
    )
    set(REMOTE_CACHE OFF)
  endif()
endif()

if(REMOTE_CACHE)
  if(NOT APPLE)
    find_program(DPKG_QUERY_EXECUTABLE NAMES dpkg-query)

    if(DPKG_QUERY_EXECUTABLE)
      find_program(CC_EXECUTABLE NAMES "$ENV{CC}"
        NO_CMAKE_PATH
        NO_CMAKE_ENVIRONMENT_PATH
        NO_CMAKE_SYSTEM_PATH
      )

      if(CC_EXECUTABLE)
        get_filename_component(CC_EXECUTABLE "${CC_EXECUTABLE}" REALPATH)

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
            set(DASHBOARD_CC_PACKAGE_VERSION
              "${DPKG_QUERY_SHOW_CC_OUTPUT_VARIABLE}"
            )
          endif()
        endif()
      endif()

      find_program(GFORTRAN_EXECUTABLE NAMES "gfortran"
        NO_CMAKE_PATH
        NO_CMAKE_ENVIRONMENT_PATH
        NO_CMAKE_SYSTEM_PATH
      )

      if(GFORTRAN_EXECUTABLE)
        get_filename_component(GFORTRAN_EXECUTABLE "${GFORTRAN_EXECUTABLE}"
          REALPATH
        )

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
            set(DASHBOARD_GFORTRAN_PACKAGE_VERSION
              "${DPKG_QUERY_SHOW_GFORTRAN_OUTPUT_VARIABLE}"
            )
          endif()
        endif()
      endif()

      find_program(Java_JAVA_EXECUTABLE NAMES "java"
        NO_CMAKE_PATH
        NO_CMAKE_ENVIRONMENT_PATH
        NO_CMAKE_SYSTEM_PATH
      )

      if(Java_JAVA_EXECUTABLE)
        get_filename_component(Java_JAVA_EXECUTABLE "${Java_JAVA_EXECUTABLE}"
          REALPATH
        )

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
            set(DASHBOARD_JAVA_PACKAGE_VERSION
              "${DPKG_QUERY_SHOW_JAVA_OUTPUT_VARIABLE}"
            )
          endif()
        endif()
      endif()

      find_program(Python_EXECUTABLE NAMES "python3"
        NO_CMAKE_PATH
        NO_CMAKE_ENVIRONMENT_PATH
        NO_CMAKE_SYSTEM_PATH
      )

      if(Python_EXECUTABLE)
        get_filename_component(Python_EXECUTABLE "${Python_EXECUTABLE}" REALPATH)

        separate_arguments(DPKG_QUERY_SEARCH_PYTHON_ARGS_LIST
          UNIX_COMMAND "-S ${Python_EXECUTABLE}"
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
            set(DASHBOARD_PYTHON_PACKAGE_VERSION
              "${DPKG_QUERY_SHOW_PYTHON_OUTPUT_VARIABLE}"
            )
          endif()
        endif()
      endif()

      if(DASHBOARD_CC_PACKAGE_VERSION AND
         DASHBOARD_GFORTRAN_PACKAGE_VERSION AND
         DASHBOARD_JAVA_PACKAGE_VERSION AND
         DASHBOARD_PYTHON_PACKAGE_VERSION
      )
        set(DASHBOARD_PACKAGE_VERSIONS
          "${COMPILER}:${DASHBOARD_CC_PACKAGE_VERSION}"
          "gfortran:${DASHBOARD_GFORTRAN_PACKAGE_VERSION}"
          "java:${DASHBOARD_JAVA_PACKAGE_VERSION}"
          "python:${DASHBOARD_PYTHON_PACKAGE_VERSION}"
        )
        string(SHA256 DASHBOARD_REMOTE_CACHE_KEY "${DASHBOARD_PACKAGE_VERSIONS}")
        set(DASHBOARD_REMOTE_CACHE
          "${DASHBOARD_REMOTE_CACHE}/v1/${DASHBOARD_REMOTE_CACHE_KEY}"
        )
      else()
        message(WARNING
          "*** Disabling remote cache because could NOT compute remote cache key"
        )
        set(REMOTE_CACHE OFF)
      endif()
    else()
      message(WARNING
        "*** Disabling remote cache because could NOT compute remote cache key"
      )
      set(REMOTE_CACHE OFF)
    endif()
  endif()
endif()
