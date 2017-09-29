# Set default compiler and generator (if not specified) or copy from environment
if(NOT DEFINED ENV{compiler})
  if(APPLE)
    message(WARNING "*** ENV{compiler} was not set; defaulting to 'clang'")
    set(COMPILER "clang")
  else()
    message(WARNING "*** ENV{compiler} was not set; defaulting to 'gcc'")
    set(COMPILER "gcc")
  endif()
else()
  set(COMPILER $ENV{compiler})
endif()
if(NOT DEFINED ENV{generator})
  message(WARNING "*** ENV{generator} was not set; defaulting to 'make'")
  set(GENERATOR "make")
else()
  set(GENERATOR $ENV{generator})
endif()

# Copy remaining configuration from environment
set(DEBUG $ENV{debug})
set(DOCUMENTATION $ENV{documentation})
set(EVERYTHING $ENV{everything})
set(MATLAB $ENV{matlab})
set(MEMCHECK $ENV{memcheck})
set(PACKAGE $ENV{package})
set(PROVISION $ENV{provision})
set(SNOPT $ENV{snopt})
set(TRACK $ENV{track})

# Verify workspace location and convert to CMake path
if(NOT DEFINED ENV{WORKSPACE})
  fatal("ENV{WORKSPACE} was not set")
endif()

file(TO_CMAKE_PATH "$ENV{WORKSPACE}" DASHBOARD_WORKSPACE)

# Determine location of git working tree
if(EXISTS "${DASHBOARD_WORKSPACE}/.git")
  set(DASHBOARD_SOURCE_DIRECTORY "${DASHBOARD_WORKSPACE}")
elseif(EXISTS ${DASHBOARD_WORKSPACE}/src/.git)
  set(DASHBOARD_SOURCE_DIRECTORY "${DASHBOARD_WORKSPACE}/src")
elseif(EXISTS "${DASHBOARD_WORKSPACE}/src/drake/.git")
  set(DASHBOARD_SOURCE_DIRECTORY "${DASHBOARD_WORKSPACE}/src/drake")
else()
  fatal("git working tree was not found")
endif()

# Set the build tree
# TODO(jamiesnape) make this ${DASHBOARD_WORKSPACE}/build
set(DASHBOARD_BINARY_DIRECTORY "${DASHBOARD_SOURCE_DIRECTORY}/build")

# Determine if build machine is "warm"
if(NOT APPLE)
  set(DASHBOARD_WARM_FILE "/tmp/WARM")
  if(EXISTS "${DASHBOARD_WARM_FILE}")
    set(DASHBOARD_WARM ON)
    message("*** This EBS volume is warm")
  else()
    set(DASHBOARD_WARM OFF)
    message("*** This EBS volume is cold")
  endif()
endif()
