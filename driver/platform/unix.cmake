# Set paths for ROS
if(ROS AND EXISTS "/opt/ros/indigo/setup.bash")
  set(ENV{ROS_HOME} "$ENV{WORKSPACE}")
  set(ENV{ROS_ROOT} /opt/ros/indigo/share/ros)
  set(ENV{ROS_ETC_DIR} /opt/ros/indigo/etc/ros)
  set(ENV{ROS_MASTER_URI} "http://localhost:11311")
  set(ENV{ROS_DISTRO} "indigo")
  unset(ENV{ROSLISP_PACKAGE_DIRECTORIES})
  set_path(ROS_PACKAGE_PATH
    /opt/ros/indigo/share
    /opt/ros/indigo/stacks)
  prepend_path(PATH /opt/ros/indigo/bin)
  prepend_path(CPATH /opt/ros/indigo/include)
  prepend_path(LD_LIBRARY_PATH /opt/ros/indigo/lib)
  prepend_path(PKG_CONFIG_PATH /opt/ros/indigo/lib/pkgconfig)
  prepend_path(PYTHONPATH /opt/ros/indigo/lib/python2.7/dist-packages)
  prepend_path(CMAKE_PREFIX_PATH /opt/ros/indigo)
endif()

# Set (non-Apple) paths for MATLAB
if(MATLAB AND NOT APPLE)
  prepend_path(PATH /usr/local/MATLAB/R2015b/bin)
endif()

# Get distribution information
if(APPLE)
  set(DASHBOARD_UNIX_DISTRIBUTION "OS X")
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
