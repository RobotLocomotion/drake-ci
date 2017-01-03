set(DASHBOARD_MEMCHECK ON)
set(DASHBOARD_INSTALL ON)
set(DASHBOARD_CONFIGURATION_TYPE "Debug")

# Set extra compile and link flags
set(DASHBOARD_EXTRA_DEBUG_FLAGS
  "-fno-omit-frame-pointer -fno-optimize-sibling-calls")
prepend_flags(DASHBOARD_C_FLAGS ${DASHBOARD_EXTRA_DEBUG_FLAGS})
prepend_flags(DASHBOARD_CXX_FLAGS ${DASHBOARD_EXTRA_DEBUG_FLAGS})
prepend_flags(DASHBOARD_FORTRAN_FLAGS ${DASHBOARD_EXTRA_DEBUG_FLAGS})

if(MEMCHECK STREQUAL "msan")
  prepend_path(LD_LIBRARY_PATH /usr/local/libcxx_msan/lib)
  prepend_flags(DASHBOARD_C_FLAGS "-I/usr/local/libcxx_msan/include/c++/v1")
  prepend_flags(DASHBOARD_CXX_FLAGS
    "-stdlib=libc++"
    "-I/usr/local/libcxx_msan/include/c++/v1")
  set(DASHBOARD_CXX_STANDARD 14)
  prepend_flags(DASHBOARD_SHARED_LINKER_FLAGS
    "-L/usr/local/libcxx_msan/lib"
    "-Wl,-rpath,/usr/local/libcxx_msan/lib"
    "-lc++abi")
endif()

set(MEMCHECK_FLAGS CTEST_MEMORYCHECK_TYPE)

if(MEMCHECK STREQUAL "asan")
  set(DASHBOARD_MEMORYCHECK_TYPE "AddressSanitizer")
  set(DASHBOARD_SANITIZE_FLAGS "-fsanitize=address")
  # TODO(jamiesnape): Enable when lcm-gen is fixed.
  # if(COMPILER STREQUAL "clang")
  #   set(DASHBOARD_SANITIZE_FLAGS
  #     "${DASHBOARD_SANITIZE_FLAGS} -fsanitize-address-use-after-scope -fsanitize-blacklist=${DASHBOARD_SOURCE_DIRECTORY}/tools/blacklist.txt")
  # endif()
  prepend_flags(DASHBOARD_C_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_CXX_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_Fortran_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_SHARED_LINKER_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  set(ENV{ASAN_OPTIONS}
    "check_initialization_order=1:detect_stack_use_after_return=1:suppressions=${DASHBOARD_SOURCE_DIRECTORY}/tools/asan.supp")
elseif(MEMCHECK STREQUAL "lsan")
  set(DASHBOARD_MEMORYCHECK_TYPE "AddressSanitizer")
  set(DASHBOARD_SANITIZE_FLAGS "-fsanitize=leak")
  if(COMPILER STREQUAL "clang")
    set(DASHBOARD_SANITIZE_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} -fsanitize-blacklist=${DASHBOARD_SOURCE_DIRECTORY}/tools/blacklist.txt")
  endif()
  prepend_flags(DASHBOARD_C_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_CXX_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_Fortran_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_SHARED_LINKER_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  set(ENV{LSAN_OPTIONS}
    "suppressions=${DASHBOARD_SOURCE_DIRECTORY}/tools/lsan.supp")
elseif(MEMCHECK STREQUAL "msan")
  set(DASHBOARD_MEMORYCHECK_TYPE "MemorySanitizer")
  set(DASHBOARD_SANITIZE_FLAGS "-fsanitize=memory")
  # TODO(jamiesnape): Enable when lcm-gen is fixed.
  # set(DASHBOARD_SANITIZE_FLAGS
  #   "-fsanitize=memory -fsanitize-blacklist=${DASHBOARD_SOURCE_DIRECTORY}/tools/blacklist.txt -fsanitize-memory-track-origins")
  prepend_flags(DASHBOARD_C_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_CXX_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_Fortran_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_SHARED_LINKER_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  set(ENV{MSAN_OPTIONS}
    "suppressions=${DASHBOARD_SOURCE_DIRECTORY}/tools/msan.supp")
elseif(MEMCHECK STREQUAL "tsan")
  set(DASHBOARD_MEMORYCHECK_TYPE "ThreadSanitizer")
  set(DASHBOARD_SANITIZE_FLAGS "-fsanitize=thread")
  if(COMPILER STREQUAL "clang")
    set(DASHBOARD_SANITIZE_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} -fsanitize-blacklist=${DASHBOARD_SOURCE_DIRECTORY}/tools/blacklist.txt")
  endif()
  prepend_flags(DASHBOARD_C_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_CXX_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_Fortran_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_SHARED_LINKER_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  set(ENV{TSAN_OPTIONS}
    "detect_deadlocks=1:second_deadlock_stack=1:suppressions=${DASHBOARD_SOURCE_DIRECTORY}/tools/tsan.supp")
elseif(MEMCHECK STREQUAL "ubsan")
  set(DASHBOARD_MEMORYCHECK_TYPE "UndefinedBehaviorSanitizer")
  set(DASHBOARD_SANITIZE_FLAGS "-fsanitize=undefined")
  if(COMPILER STREQUAL "clang")
    set(DASHBOARD_SANITIZE_FLAGS
      "${DASHBOARD_SANITIZE_FLAGS} -fsanitize-blacklist=${DASHBOARD_SOURCE_DIRECTORY}/tools/blacklist.txt")
  endif()
  prepend_flags(DASHBOARD_C_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_CXX_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_Fortran_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  prepend_flags(DASHBOARD_SHARED_LINKER_FLAGS ${DASHBOARD_SANITIZE_FLAGS})
  set(ENV{UBSAN_OPTIONS}
    "suppressions=${DASHBOARD_SOURCE_DIRECTORY}/tools/ubsan.supp")
elseif(MEMCHECK STREQUAL "valgrind")
  set(DASHBOARD_MEMORYCHECK_TYPE "Valgrind")
  find_program(DASHBOARD_MEMORYCHECK_COMMAND NAMES "valgrind")
  set(CTEST_MEMORYCHECK_COMMAND "${DASHBOARD_MEMORYCHECK_COMMAND}")
  set(CTEST_MEMORYCHECK_COMMAND_OPTIONS
    "--show-leak-kinds=definite,possible --trace-children=yes --trace-children-skip=/bin/*,/usr/bin/*,/usr/local/bin/* --track-origins=yes")
  set(CTEST_MEMORYCHECK_SUPPRESSIONS_FILE
    "${DASHBOARD_SOURCE_DIRECTORY}/tools/valgrind-cmake.supp")
  if(NOT EXISTS "${CTEST_MEMORYCHECK_SUPPRESSIONS_FILE}")
    fatal("CTEST_MEMORYCHECK_SUPPRESSIONS_FILE was not found")
  endif()
  set(ENV{GTEST_DEATH_TEST_USE_FORK} 1)
  list(APPEND MEMCHECK_FLAGS
    CTEST_MEMORYCHECK_COMMAND
    CTEST_MEMORYCHECK_COMMAND_OPTIONS
    CTEST_MEMORYCHECK_SUPPRESSIONS_FILE
  )
else()
  fatal("CTEST_MEMORYCHECK_TYPE was not set")
endif()

set(CTEST_MEMORYCHECK_TYPE "${DASHBOARD_MEMORYCHECK_TYPE}")

# Disable Python (and maybe Fortran) when using Valgrind or sanitizers, as
# they tend to make more trouble than they are worth
cache_append(DISABLE_PYTHON BOOL ON)
if(MEMCHECK MATCHES "^(asan|lsan|msan|tsan|ubsan)$")
  cache_append(DISABLE_FORTRAN BOOL ON)
endif()
