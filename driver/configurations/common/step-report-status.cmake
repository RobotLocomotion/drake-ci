# -*- mode: cmake; -*-
# vi: set ft=cmake:

# Determine build result and (possibly) set status message
if(DASHBOARD_FAILURE)
  report_status(FAILURE "FAILURE DURING %STEPS%")
else()
  if(DASHBOARD_UNSTABLE)
    report_status(UNSTABLE "UNSTABLE DUE TO %STEPS% FAILURES")
  else()
    file(WRITE "${DASHBOARD_WORKSPACE}/RESULT" "SUCCESS")
  endif()
endif()

# Report build result and CDash links
set(end_status_message "CTest Result: ${DASHBOARD_MESSAGE}")
if (DASHBOARD_CDASH_URL AND DASHBOARD_SUBMIT)
  file(WRITE "${DASHBOARD_WORKSPACE}/CDASH" "${DASHBOARD_CDASH_URL}")
  list(APPEND end_status_message
    "CDash URL: ${DASHBOARD_CDASH_URL}")
endif()
notice(${end_status_message})
