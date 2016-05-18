# this is a sample shell script to run ctest_driver_script.cmake
# locally without Jenkins.
# 1. git clone drake into path specified in WORKSPACE
# 2. uppdate variables in this script to build you want, including
#    the path to cmake.
# 3. run script
set WORKSPACE=c:/Users/hoffman/Work/drake/draketest
set compiler=msvc-ninja-32
set debug=true
set coverage=false
set track=experimental
set BUILD_ID=buildid
set PATH=c:\Program Files (x86)\CMake\bin;C:\msys64\usr\bin;C:\msys64\usr\lib\git-core
cd c:\Users\hoffman\Work\drake\drake-ci
ctest -C Release -DUSE_NINJA=TRUE -Dbuildname=bills-test-%compiler% -Dsite=bills-laptop -S ctest_driver_script.cmake -VV --no-compress-output --output-on-failure --parallel 4 --timeout 1000 -O build.log

