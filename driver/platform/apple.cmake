prepend_path(PATH
  /opt/X11/bin
  /usr/local/opt/python/libexec/bin
  /usr/local/bin
  /usr/bin
  /bin
  /usr/local/sbin
  /usr/sbin
  /sbin)

if(MATLAB)
  prepend_path(PATH
    /Applications/MATLAB_R2015b.app/bin
    /Applications/MATLAB_R2015b.app/runtime/maci64)
endif()
