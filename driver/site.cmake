# -*- mode: cmake; -*-
# vi: set ft=cmake:

# Set site
string(REGEX REPLACE "(.*) - (.*) (.*)" "\\2"
  DASHBOARD_NODE_NAME "${DASHBOARD_NODE_NAME}")
set(CTEST_SITE "${DASHBOARD_NODE_NAME}")

# set model and track for submission
set(DASHBOARD_MODEL "Experimental")
if(TRACK STREQUAL "continuous")
  set(DASHBOARD_TRACK "Continuous")
elseif(TRACK MATCHES "(nightly|weekly)")
  set(DASHBOARD_TRACK "Nightly")
elseif(TRACK STREQUAL "staging")
  set(DASHBOARD_TRACK "Staging")
else()
  set(DASHBOARD_TRACK "Experimental")
endif()

# Set build id
if(DEFINED ENV{BUILD_ID})
  string(STRIP "$ENV{BUILD_ID}" DASHBOARD_JENKINS_BUILD_ID)
  set(DASHBOARD_LABEL "jenkins-${DASHBOARD_JOB_NAME}-${DASHBOARD_JENKINS_BUILD_ID}")
  set_property(GLOBAL PROPERTY Label "${DASHBOARD_LABEL}")
else()
  message(WARNING "*** ENV{BUILD_ID} was not set")
  set(DASHBOARD_LABEL)
endif()

# Set git commit
if(DEFINED ENV{GIT_COMMIT})
  string(STRIP "$ENV{GIT_COMMIT}" DASHBOARD_GIT_COMMIT)
else()
  message(WARNING "*** ENV{GIT_COMMIT} was not set")
  set(DASHBOARD_GIT_COMMIT)
endif()

# Set pull request id
if(DEFINED ENV{CHANGE_ID})
  string(STRIP "$ENV{CHANGE_ID}" CTEST_CHANGE_ID)
  string(STRIP "$ENV{CHANGE_TITLE}" DASHBOARD_CHANGE_TITLE)
  string(STRIP "$ENV{CHANGE_URL}" DASHBOARD_CHANGE_URL)
endif()
if(CTEST_CHANGE_ID)
  string(LENGTH "${DASHBOARD_CHANGE_TITLE}" DASHBOARD_CHANGE_TITLE_LENGTH)
  if(DASHBOARD_CHANGE_TITLE_LENGTH GREATER 30)
    string(SUBSTRING "${DASHBOARD_CHANGE_TITLE}" 0 27
      DASHBOARD_CHANGE_TITLE_SUBSTRING)
    set(DASHBOARD_CHANGE_TITLE_SHORT "${DASHBOARD_CHANGE_TITLE_SUBSTRING}...")
  else()
    set(DASHBOARD_CHANGE_TITLE_SHORT "${DASHBOARD_CHANGE_TITLE}")
  endif()
  set(DASHBOARD_BUILD_DESCRIPTION
    "*** Build Description: <a title=\"${DASHBOARD_CHANGE_TITLE}\" href=\"${DASHBOARD_CHANGE_URL}\">PR #${CTEST_CHANGE_ID}</a>: ${DASHBOARD_CHANGE_TITLE_SHORT}")
else()
  string(SUBSTRING "${DASHBOARD_GIT_COMMIT}" 0 7 DASHBOARD_GIT_COMMIT_SUBSTRING)
  set(DASHBOARD_BUILD_DESCRIPTION
    "*** Build Description: <a title=\"${DASHBOARD_GIT_COMMIT}\" href=\"https://github.com/RobotLocomotion/drake/commit/${DASHBOARD_GIT_COMMIT}\">${DASHBOARD_GIT_COMMIT_SUBSTRING}</a>")
endif()
message("${DASHBOARD_BUILD_DESCRIPTION}")
