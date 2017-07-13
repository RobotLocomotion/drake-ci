set(DASHBOARD_COVERAGE ON)
set(DASHBOARD_INSTALL ON)
set(DASHBOARD_CONFIGURATION_TYPE "Debug")

# Set extra compile and link flags
set(DASHBOARD_COVERAGE_FLAGS "-fprofile-arcs -ftest-coverage")
set(DASHBOARD_EXTRA_DEBUG_FLAGS "-O0")
prepend_flags(DASHBOARD_C_FLAGS
  ${DASHBOARD_COVERAGE_FLAGS}
  ${DASHBOARD_EXTRA_DEBUG_FLAGS})
prepend_flags(DASHBOARD_CXX_FLAGS
  ${DASHBOARD_COVERAGE_FLAGS}
  ${DASHBOARD_EXTRA_DEBUG_FLAGS})
prepend_flags(DASHBOARD_FORTRAN_FLAGS
  ${DASHBOARD_COVERAGE_FLAGS}
  ${DASHBOARD_EXTRA_DEBUG_FLAGS})
prepend_flags(DASHBOARD_SHARED_LINKER_FLAGS
  ${DASHBOARD_COVERAGE_FLAGS})

# Find coverage tool
if(COMPILER STREQUAL "clang")
  if(APPLE)
    find_program(DASHBOARD_XCRUN_COMMAND xcrun)
    if(NOT DASHBOARD_XCRUN_COMMAND)
      fatal("xcrun was not found")
    endif()
    execute_process(COMMAND "${DASHBOARD_XCRUN_COMMAND}" -f llvm-cov
      RESULT_VARIABLE DASHBOARD_XCRUN_RESULT_VARIABLE
      OUTPUT_VARIABLE DASHBOARD_XCRUN_OUTPUT_VARIABLE
      ERROR_VARIABLE DASHBOARD_XCRUN_ERROR_VARIABLE
      OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(DASHBOARD_XCRUN_RESULT_VARIABLE EQUAL 0)
      set(DASHBOARD_COVERAGE_COMMAND "${DASHBOARD_XCRUN_OUTPUT_VARIABLE}")
    else()
      message("${DASHBOARD_XCRUN_OUTPUT_VARIABLE}")
      message("${DASHBOARD_XCRUN_ERROR_VARIABLE}")
    endif()
  else()
    find_program(DASHBOARD_COVERAGE_COMMAND llvm-cov)
  endif()
  if(NOT DASHBOARD_COVERAGE_COMMAND)
    fatal("llvm-cov was not found")
  endif()
  set(DASHBOARD_COVERAGE_EXTRA_FLAGS "gcov")
elseif(COMPILER STREQUAL "gcc")
  find_program(DASHBOARD_COVERAGE_COMMAND gcov${DASHBOARD_GNU_COMPILER_SUFFIX})
  if(NOT DASHBOARD_COVERAGE_COMMAND)
    fatal("gcov${DASHBOARD_GNU_COMPILER_SUFFIX} was not found")
  endif()
else()
  fatal("CTEST_COVERAGE_COMMAND was not set")
endif()

set(CTEST_COVERAGE_COMMAND "${DASHBOARD_COVERAGE_COMMAND}")
set(CTEST_COVERAGE_EXTRA_FLAGS "${DASHBOARD_COVERAGE_EXTRA_FLAGS}")

list(APPEND CTEST_CUSTOM_COVERAGE_EXCLUDE
  ".*/python/.*"
  ".*/test/.*"
  ".*/thirdParty/.*"
)

if(NOT MATLAB)
  list(APPEND CTEST_CUSTOM_COVERAGE_EXCLUDE
    ".*/bindings/.*"
    ".*/matlab/.*"
  )
endif()

# Disable Fortran if using Clang, as they do not play nicely together. Also
# disable Python as the Python bindings depend on IPOPT, which depends on
# Fortran.
if(COMPILER MATCHES "^(clang|scan-build)$")
  cache_append(DISABLE_FORTRAN BOOL ON)
  cache_append(DISABLE_PYTHON BOOL ON)
endif()
