# -*- mode: cmake; -*-
# vi: set ft=cmake:

if(NOT APPLE)
  # On Resolute and newer, amd64 unprovisioned images default to the v3
  # variant. Reset this for jobs which request other variants.
  if(PROVISION AND ARCH_AND_VARIANT STREQUAL "amd64")
    if(NOT EXISTS "/etc/apt/apt.conf.d/99enable-amd64v3")
      fatal("Could not find conf file enabling v3 architecture variant")
    endif()
    file(REMOVE "/etc/apt/apt.conf.d/99enable-amd64v3")
    execute_process(
      COMMAND "apt-get update"
      COMMAND "apt-get upgrade" "-y"
      RESULT_VARIABLE ARCH_UPGRADE_RESULT
      ERROR_VARIABLE ARCH_UPGRADE_ERROR
    )
    if(NOT ARCH_UPGRADE_RESULT)
      fatal("Failed to apt-get update && apt-get upgrade for v1 packages: ${ARCH_UPGRADE_ERROR}")
    endif()
  endif()

  # Determine the architecture/variant.
  execute_process(
    COMMAND
      "dpkg-query" "--show"
      # Use the first of Architecture-Variant or Architecture that is defined,
      # since the former isn't always available/applicable.
      [==[--showformat=${Architecture-Variant}\n${Architecture}\n]==]
      "libc6"
    COMMAND
      "grep" "-m" "1" "."
    OUTPUT_VARIABLE DASHBOARD_DEB_ARCH
    RESULT_VARIABLE DASHBOARD_DEB_ARCH_RESULT
    ERROR_VARIABLE DASHBOARD_DEB_ARCH_ERROR
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  if (NOT DASHBOARD_DEB_ARCH_RESULT EQUAL 0 OR DASHBOARD_DEB_ARCH STREQUAL "")
    fatal("Unable to determine architecture: ${DASHBOARD_DEB_ARCH_ERROR}")
  endif()
  if (NOT DASHBOARD_DEB_ARCH STREQUAL ARCH_AND_VARIANT)
    fatal("Failed to set the intended architecture variant: got ${DASHBOARD_DEB_ARCH}, expected ${ARCH_AND_VARIANT}")
  endif()
endif()
