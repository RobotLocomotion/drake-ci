prepend_path(PATH
  /usr/local/opt/python@2/libexec/bin
  /usr/local/opt/python@2/bin
  /usr/local/bin
  /usr/bin
  /bin
  /usr/local/sbin
  /usr/sbin
  /sbin)

if(MATLAB)
  prepend_path(PATH
    /Applications/MATLAB_R2017a.app/bin
    /Applications/MATLAB_R2017a.app/runtime/maci64)
endif()
