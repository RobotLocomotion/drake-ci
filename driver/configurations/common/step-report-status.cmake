set(DASHBOARD_MESSAGE "CTest Result: ${DASHBOARD_MESSAGE}")

if(DASHBOARD_LABEL)
  set(DASHBOARD_CDASH_SUPERBUILD_URL_MESSAGE
    "CDash Superbuild URL: https://${DASHBOARD_CDASH_SERVER}/index.php?project=${DASHBOARD_SUPERBUILD_PROJECT_NAME}&showfilters=1&filtercount=2&showfilters=1&filtercombine=and&field1=label&compare1=61&value1=${DASHBOARD_LABEL}&field2=buildstarttime&compare2=84&value2=now")
else()
  set(DASHBOARD_CDASH_SUPERBUILD_URL_MESSAGE "CDash Superbuild URL:")
endif()

if(NOT DASHBOARD_SUPERBUILD_FAILURE AND DASHBOARD_LABEL)
  set(DASHBOARD_CDASH_URL_MESSAGE
    "CDash URL: https://${DASHBOARD_CDASH_SERVER}/index.php?project=${DASHBOARD_PROJECT_NAME}&showfilters=1&filtercount=2&showfilters=1&filtercombine=and&field1=label&compare1=61&value1=${DASHBOARD_LABEL}&field2=buildstarttime&compare2=84&value2=now")
else()
  set(DASHBOARD_CDASH_URL_MESSAGE "CDash URL:")
endif()

# Report build result and CDash links
notice(
  "${DASHBOARD_MESSAGE}"
  "${DASHBOARD_CDASH_SUPERBUILD_URL_MESSAGE}"
  "${DASHBOARD_CDASH_URL_MESSAGE}"
)
