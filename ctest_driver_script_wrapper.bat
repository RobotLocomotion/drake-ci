ECHO ON
SET PATH=C:\Program Files (x86)\CMake\bin;%PATH%
ctest -Dbuildname=%JOB_NAME% -Dsite=%NODE_NAME% -S %WORKSPACE%/ci/ctest_driver_script.cmake --extra-verbose --no-compress-output --output-on-failure
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
