# Check for git errors
# TODO: Remove when no longer trying to track down underlying cause
if(EXISTS "${DASHBOARD_WORKSPACE}/GIT_ERROR")
  append_step_status("GIT" UNSTABLE)
endif()

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
