# Determine build result and (possibly) set status message
if(DASHBOARD_FAILURE)
  report_status(FAILURE "FAILURE DURING %STEPS%")
else()
  if(DASHBOARD_UNSTABLE)
    report_status(UNSTABLE "UNSTABLE DUE TO %STEPS% FAILURES")
  else()
    file(WRITE "${DASHBOARD_WORKSPACE}/SUCCESS")
  endif()
endif()

# Report build result and CDash links
notice(
  "CTest Result: ${DASHBOARD_MESSAGE}"
  ${DASHBOARD_CDASH_URL_MESSAGES}
)
