#!/bin/bash

# Copyright © 2020-2025 Dell Inc. or its subsidiaries. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#!/bin/bash
#
# Copyright (c) 2021 Dell Inc., or its subsidiaries. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
DARK_GRAY='\033[1;30m'
NC='\033[0m' # No Color

function decho() {
  if [ -n "${DEBUGLOG}" ]; then
    echo "$@" | tee -a "${DEBUGLOG}"
  fi
}

function debuglog_only() {
  if [ -n "${DEBUGLOG}" ]; then
    echo "$@" >> "${DEBUGLOG}"
  fi
}

function log() {
  case $1 in
  separator)
    decho "---------------------------------------------------------------------------------"
    ;;
  error)
    decho
    log separator
    printf "${RED}Error: $2\n"
    printf "${RED}Installation cannot continue${NC}\n"
    debuglog_only "Error: $2"
    debuglog_only "Installation cannot continue"
    exit 1
    ;;
  step)
    printf "|\n|- %-65s" "$2"
    debuglog_only "${2}"
    ;;
  small_step)
    printf "%-61s" "$2"
    debuglog_only "${2}"
    ;;
  section)
    log separator
    printf "> %s\n" "$2"
    debuglog_only "${2}"
    log separator
    ;;
  smart_step)
    if [[ $3 == "small" ]]; then
      log small_step "$2"
    else
      log step "$2"
    fi
    ;;
  arrow)
    printf "  %s\n  %s" "|" "|--> "
    ;;
  step_success)
    printf "${GREEN}Success${NC}\n"
    ;;
  step_failure)
    printf "${RED}Failed${NC}\n"
    ;;
  step_warning)
    printf "${YELLOW}Warning${NC}\n"
    ;;
  info)
    printf "${DARK_GRAY}%s${NC}\n" "$2"
    ;;
  passed)
    printf "${GREEN}Success${NC}\n"
    ;;
  warnings)
    printf "${YELLOW}Warnings:${NC}\n"
    ;;
  errors)
    printf "${RED}Errors:${NC}\n"
    ;;
  *)
    echo -n "Unknown"
    ;;
  esac
}

function check_error() {
  if [[ $1 -ne 0 ]]; then
    log step_failure
  else
    log step_success
  fi
}

function run_command() {
  local RC=0
  if [ -n "${DEBUGLOG}" ]; then
    local ME=$(basename "${0}")
    echo "---------------" >> "${DEBUGLOG}"
    echo "${ME}:${BASH_LINENO[0]} - Running command: $@" >> "${DEBUGLOG}"
    debuglog_only "Results:"
    eval "$@" | tee -a "${DEBUGLOG}"
    RC=${PIPESTATUS[0]}
    echo "---------------" >> "${DEBUGLOG}"
  else
    eval "$@"
    RC=$?
  fi
  return $RC
}

function check_versions_lower(){
  if [[ $1 == $2 ]]; then
    return 1
  else
    low=$(echo -e "$1\n$2" | sort --version-sort | head --lines=1)
    if [[ $low == $1 ]]; then
      return 0
    else
      return 1
    fi
  fi
}

function check_versions_greater(){
  if [[ $1 == $2 ]]; then
    return 1
  else
    low=$(echo -e "$1\n$2" | sort --version-sort | head --lines=1)
    if [[ $low == $2 ]]; then
      return 0
    else
      return 1
    fi
  fi
}
