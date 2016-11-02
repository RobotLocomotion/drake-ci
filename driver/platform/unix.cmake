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

if(MATLAB AND NOT APPLE)
  prepend_path(PATH /usr/local/MATLAB/R2015b/bin)
endif()