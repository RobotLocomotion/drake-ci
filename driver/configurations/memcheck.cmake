set(DASHBOARD_MEMCHECK ON)
set(DASHBOARD_INSTALL ON)
set(DASHBOARD_CONFIGURATION_TYPE "Debug")

# Set extra compile and link flags
set(DASHBOARD_EXTRA_DEBUG_FLAGS "-O1 -fno-omit-frame-pointer")
prepend_flags(DASHBOARD_C_FLAGS ${DASHBOARD_EXTRA_DEBUG_FLAGS})
prepend_flags(DASHBOARD_CXX_FLAGS ${DASHBOARD_EXTRA_DEBUG_FLAGS})
prepend_flags(DASHBOARD_FORTRAN_FLAGS ${DASHBOARD_EXTRA_DEBUG_FLAGS})

if(MEMCHECK STREQUAL "msan")
  prepend_path(LD_LIBRARY_PATH /usr/local/libcxx_msan/lib)
  prepend_flags(DASHBOARD_C_FLAGS "-I/usr/local/libcxx_msan/include")
  prepend_flags(DASHBOARD_CXX_FLAGS
    "-stdlib=libc++"
    "-L/usr/local/libcxx_msan/lib"
    "-lc++abi"
    "-I/usr/local/libcxx_msan/include"
    "-I/usr/local/libcxx_msan/include/c++/v1")
  set(DASHBOARD_CXX_STANDARD 11)
endif()

if(MEMCHECK STREQUAL "asan")
  set(DASHBOARD_MEMORYCHECK_TYPE "AddressSanitizer")
  set(DASHBOARD_SANITIZE_FLAGS "-fsanitize=address")
  prepend_flags(DASHBOARD_C_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_CXX_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_Fortran_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_SHARED_LINKER_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
elseif(MEMCHECK STREQUAL "msan")
  set(DASHBOARD_MEMORYCHECK_TYPE "MemorySanitizer")
  set(DASHBOARD_SANITIZE_FLAGS "-fsanitize=memory")
  prepend_flags(DASHBOARD_C_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_CXX_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_Fortran_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_SHARED_LINKER_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
elseif(MEMCHECK STREQUAL "tsan")
  set(DASHBOARD_MEMORYCHECK_TYPE "ThreadSanitizer")
  set(DASHBOARD_SANITIZE_FLAGS "-fsanitize=thread")
  prepend_flags(DASHBOARD_C_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_CXX_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_Fortran_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_SHARED_LINKER_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  set(DASHBOARD_POSITION_INDEPENDENT_CODE ON)
elseif(MEMCHECK STREQUAL "valgrind")
  set(DASHBOARD_MEMORYCHECK_TYPE "Valgrind")
  find_program(DASHBOARD_MEMORYCHECK_COMMAND NAMES "valgrind")
  set(CTEST_MEMORYCHECK_COMMAND "${DASHBOARD_MEMORYCHECK_COMMAND}")
  set(CTEST_MEMORYCHECK_COMMAND_OPTIONS
    "--show-leak-kinds=definite,possible --trace-children=yes --trace-children-skip=/bin/*,/usr/bin/*,/usr/local/bin/*,/usr/local/MATLAB/*,/Applications/*,${DASHBOARD_WORKSPACE}/build/install/bin/directorPython")
  set(CTEST_MEMORYCHECK_SUPPRESSIONS_FILE
    "${DASHBOARD_WORKSPACE}/drake/valgrind.supp")
  if(NOT EXISTS "${DASHBOARD_WORKSPACE}/drake/valgrind.supp")
    fatal("CTEST_MEMORYCHECK_SUPPRESSIONS_FILE was not found")
  endif()
  set(ENV{GTEST_DEATH_TEST_USE_FORK} 1)
else()
  fatal("CTEST_MEMORYCHECK_TYPE was not set")
endif()

set(CTEST_MEMORYCHECK_TYPE "${DASHBOARD_MEMORYCHECK_TYPE}")
