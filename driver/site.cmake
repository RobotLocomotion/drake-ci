# Set site
if(DEFINED site)
  if(APPLE)
    string(REGEX REPLACE "(.*)_(.*)" "\\1" DASHBOARD_SITE "${site}")
  else()
    string(REGEX REPLACE "(.*) (.*)" "\\1" DASHBOARD_SITE "${site}")
  endif()
  set(CTEST_SITE "${DASHBOARD_SITE}")
else()
  message(WARNING "*** CTEST_SITE was not set")
endif()

# Set build track
if(NOT TRACK)
  set(TRACK "experimental")
endif()

# Set build name
if(DEFINED buildname)
  set(DASHBOARD_BUILD_NAME "${buildname}")
  if(TRACK STREQUAL "experimental")
    if(DEBUG)
      set(DASHBOARD_BUILD_NAME "${DASHBOARD_BUILD_NAME}-debug")
    else()
      set(DASHBOARD_BUILD_NAME "${DASHBOARD_BUILD_NAME}-release")
    endif()
  endif()
else()
  message(WARNING "*** DASHBOARD_BUILD_NAME was not set")
endif()

# set model and track for submission
set(DASHBOARD_MODEL "Experimental")
if(TRACK STREQUAL "continuous")
  set(DASHBOARD_TRACK "Continuous")
elseif(TRACK STREQUAL "nightly")
  set(DASHBOARD_TRACK "Nightly")
else()
  set(DASHBOARD_TRACK "Experimental")
endif()

# Set build id
if(DEFINED ENV{BUILD_ID})
  set(DASHBOARD_LABEL "jenkins-${DASHBOARD_BUILD_NAME}-$ENV{BUILD_ID}")
  set_property(GLOBAL PROPERTY Label "${DASHBOARD_LABEL}")
else()
  message(WARNING "*** ENV{BUILD_ID} was not set")
  set(DASHBOARD_LABEL "")
endif()

# Set pull request id
if(DEFINED ENV{ghprbPullId})
  set(CTEST_CHANGE_ID "$ENV{ghprbPullId}")
  set(DASHBOARD_CHANGE_TITLE "$ENV{ghprbPullTitle}")
  string(LENGTH "${DASHBOARD_CHANGE_TITLE}" DASHBOARD_CHANGE_TITLE_LENGTH)
  if(DASHBOARD_CHANGE_TITLE_LENGTH GREATER 30)
    string(SUBSTRING "${DASHBOARD_CHANGE_TITLE}" 0 27
      DASHBOARD_CHANGE_TITLE_SUBSTRING)
    set(DASHBOARD_CHANGE_TITLE "${DASHBOARD_CHANGE_TITLE_SUBSTRING}...")
  endif()
  set(DASHBOARD_BUILD_DESCRIPTION
    "*** Build Description: <a title=\"$ENV{ghprbPullTitle}\" href=\"$ENV{ghprbPullLink}\">PR ${CTEST_CHANGE_ID}</a>: ${DASHBOARD_CHANGE_TITLE}")
  message("${DASHBOARD_BUILD_DESCRIPTION}")
endif()
