REM This is a sample Windows batch script to run ctest_driver_script.cmake
REM locally without Jenkins.
REM 1. Update variables in this script to build you want, including the path to
REM    the cmake executable.
REM 2. Clone drake into the path specified in %WORKSPACE%.
REM 3. Run this script.

SET compiler=msvc-ninja-64
SET debug=false
SET matlab=false
SET minimal=false
SET openSource=true
SET track=experimental

SET BUILD_ID=0
SET JOB_NAME=windows-%compiler%-experimental
SET NODE_NAME=%COMPUTERNAME%
SET WORKSPACE=%HOMEPATH%\workspace\%JOB_NAME%

SET PATH=C:\Program Files\CMake\bin;C:\Program Files (x86)\CMake\bin;%PATH%

ctest -Dbuildname=%JOB_NAME% -Dsite=%NODE_NAME% -S %WORKSPACE%/ci/ctest_driver_script.cmake --extra-verbose --output-on-failure
if EXIST %WORKSPACE%/FAILURE (
  EXIT /B 1
)
if EXIST %WORKSPACE%/SUCCESS (
  EXIT /B 0
)
if EXIST %WORKSPACE%/UNSTABLE (
  EXIT /B 0
)
EXIT /B 1
