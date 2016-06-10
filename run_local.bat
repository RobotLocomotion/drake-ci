# This is a sample Windows batch script to run ctest_driver_script.cmake locally
# without Jenkins.
# 1. Update variables in this script to build you want, including the path to
#    the cmake executable.
# 2. Clone drake into the path specified in %WORKSPACE%.
# 3. Run this script.

SET compiler = msvc-ninja-64
SET debug = false
SET matlab = false
SET openSource = false
SET track = experimental

SET BUILD_ID = 0
SET JOB_NAME = windows-experimental
SET NODE_NAME = %COMPUTERNAME%
SET WORKSPACE = %HOMEPATH%\workspace\windows-experimental

SET PATH = "C:\Program Files (x86)\CMake\bin;%PATH%"

ctest -Dbuildname=%JOB_NAME% -Dsite=%NODE_NAME% -S %WORKSPACE%/ci/ctest_driver_script.cmake --extra-verbose --output-on-failure
if EXIST %WORKSPACE%/FAILURE (
  EXIT 1
)
if EXIST %WORKSPACE%/SUCCESS (
  EXIT 0
)
if EXIST %WORKSPACE%/UNSTABLE (
  EXIT 0
)
EXIT 1
