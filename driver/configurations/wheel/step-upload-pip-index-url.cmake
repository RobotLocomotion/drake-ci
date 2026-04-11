# -*- mode: cmake; -*-
# vi: set ft=cmake:

# This step should only be executing after a nightly wheel build (for any
# distribution) is complete.  Experimental / staging builds should NOT
# regenerate the pip nightly index.
if(DASHBOARD_TRACK STREQUAL "Nightly")
  if(DASHBOARD_FAILURE OR DASHBOARD_UNSTABLE)
    notice("CTest Status: NOT GENERATING PIP INDEX URL BECAUSE WHEEL BUILD WAS NOT SUCCESSFUL")
  else()
    notice("CTest Status: GENERATING PIP INDEX URL")
    generate_pip_index_url()
  endif()
endif()
