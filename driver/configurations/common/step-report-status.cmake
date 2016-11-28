set(DASHBOARD_MESSAGE "CTest Result: ${DASHBOARD_MESSAGE}")

# Report build result and CDash links
notice(
  ${DASHBOARD_MESSAGE}
  ${DASHBOARD_CDASH_URL_MESSAGES}
)
