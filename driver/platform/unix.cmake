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

# Set (non-Apple) paths for MATLAB
if(MATLAB AND NOT APPLE)
  prepend_path(PATH /usr/local/MATLAB/R2017a/bin)
endif()
