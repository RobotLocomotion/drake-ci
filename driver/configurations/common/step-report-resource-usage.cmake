# -*- mode: cmake; -*-
# vi: set ft=cmake:

# Disk usage

execute_process(COMMAND df -h "${DASHBOARD_TEMP_DIR}"
  OUTPUT_VARIABLE dashboard_temp_dir_usage
  COMMAND_ECHO NONE
  ERROR_QUIET
  OUTPUT_STRIP_TRAILING_WHITESPACE)

notice("Disk usage for ${DASHBOARD_TEMP_DIR}:\n ${dashboard_temp_dir_usage}")

if(NOT DASHBOARD_TEMP_DIR STREQUAL "/tmp")
  execute_process(COMMAND df -h "/tmp"
    OUTPUT_VARIABLE tmp_usage
    COMMAND_ECHO NONE
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE)

  notice("Disk usage for /tmp:\n ${tmp_usage}")
endif()

# Overall memory usage

# macOS doesn't have free...
if(APPLE)
  set(MEM_CMD "top -l 1 -s 0 | grep PhysMem")
else()
  set(MEM_CMD "free -m")
endif()

execute_process(COMMAND bash -c "${MEM_CMD}"
  OUTPUT_VARIABLE dashboard_mem_usage
  COMMAND_ECHO NONE
  ERROR_QUIET
  OUTPUT_STRIP_TRAILING_WHITESPACE)

notice("Memory usage:\n ${dashboard_mem_usage}")

# CPU and memory usage by process

# This command has been carefully constructed to contain only options
# supported on both Ubuntu and macOS.
# `ps` differs slightly on the two systems for historical reasons.
# * get process ID, user, cpu+mem usage, and command
# * print the header before (reverse-)sorting by memory
# * print the top 10 processes (plus the header)
set(PS_CMD "ps -o pid,user,%cpu,%mem,comm -ax |\
            (read -r; printf \"%s\\n\" \"$REPLY\"; sort -brk 4) |\
            head -n 11")

execute_process(COMMAND bash -c "${PS_CMD}"
  OUTPUT_VARIABLE dashboard_mem_proc
  COMMAND_ECHO NONE
  ERROR_QUIET
  OUTPUT_STRIP_TRAILING_WHITESPACE)

notice("Processes using most memory:\n ${dashboard_mem_proc}")
