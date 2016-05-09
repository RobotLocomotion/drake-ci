# this is a sample shell script to run ctest_driver_script.cmake
# locally without Jenkins.
# 1. git clone drake into path specified in WORKSPACE
# 2. uppdate variables in this script to build you want, including
#    the path to cmake.
# 3. run script
export WORKSPACE=c:/Users/hoffman/Work/drake/draketest
export compiler=msvc-64
export coverage=false
export track=experimental
export BUILD_ID=buildid
export PATH=/c/Program\ Files\ \(x86\)/CMake/bin:/c/Python27:${PATH}

ctest -C Release -Dbuildname=bills-test -Dsite=bills-laptop -S ctest_driver_script.cmake -VV --no-compress-output --output-on-failure --parallel 4 --timeout 1000 -O build.log

