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

# Set paths for ROS
if(ROS)
  if(DASHBOARD_UNIX_DISTRIBUTION_VERSION VERSION_LESS 16.04)
    set(DASHBOARD_ROS_DISTRO indigo)
  else()
    set(DASHBOARD_ROS_DISTRO kinetic)
  endif()
  set(DASHBOARD_ROS_DIR "/opt/ros/${DASHBOARD_ROS_DISTRO}")
  set(ENV{ROS_HOME} "$ENV{WORKSPACE}")
  set(ENV{ROS_ROOT} "${DASHBOARD_ROS_DIR}/share/ros")
  set(ENV{ROS_ETC_DIR} "${DASHBOARD_ROS_DIR}/etc/ros")
  set(ENV{ROS_MASTER_URI} "http://localhost:11311")
  set(ENV{ROS_DISTRO} "${DASHBOARD_ROS_DISTRO}")
  unset(ENV{ROSLISP_PACKAGE_DIRECTORIES})
  set_path(ROS_PACKAGE_PATH
    "${DASHBOARD_ROS_DIR}/share"
    "${DASHBOARD_ROS_DIR}/stacks")
  prepend_path(PATH "${DASHBOARD_ROS_DIR}/bin")
  prepend_path(CPATH "${DASHBOARD_ROS_DIR}/include")
  prepend_path(LD_LIBRARY_PATH "${DASHBOARD_ROS_DIR}/lib")
  prepend_path(PKG_CONFIG_PATH "${DASHBOARD_ROS_DIR}/lib/pkgconfig")
  prepend_path(PYTHONPATH "${DASHBOARD_ROS_DIR}/lib/python2.7/dist-packages")
  prepend_path(CMAKE_PREFIX_PATH "${DASHBOARD_ROS_DIR}")

  # Set TERM to dumb to work around tput errors from catkin-tools
  # https://github.com/catkin/catkin_tools/issues/157#issuecomment-221975716
  set(ENV{TERM} "dumb")
endif()

# Override git executable
cache_append(GIT_EXECUTABLE PATH "${DASHBOARD_TOOLS_DIR}/git-wrapper.bash")

# Set (non-Apple) paths for MATLAB
if(MATLAB AND NOT APPLE)
  if(DASHBOARD_UNIX_DISTRIBUTION_VERSION VERSION_LESS 16.04)
    prepend_path(PATH /usr/local/MATLAB/R2015b/bin)
  endif()
  prepend_path(PATH /usr/local/MATLAB/R2017a/bin)
endif()
