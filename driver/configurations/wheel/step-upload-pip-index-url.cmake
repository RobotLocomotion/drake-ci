# -*- mode: cmake; -*-
# vi: set ft=cmake:

if(DASHBOARD_FAILURE OR DASHBOARD_UNSTABLE)
  notice("CTest Status: NOT GENERATING PIP INDEX URL BECAUSE WHEEL BUILD WAS NOT SUCCESSFUL")
else()
  notice("CTest Status: GENERATING PIP INDEX URL")
  generate_pip_index_url()
endif()
