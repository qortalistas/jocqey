#!/bin/sh
. ./jocqey.lib.sh || echo "jocqey.lib.sh not found"
stop_qortal
#realpath .


#!/usr/bin/env bash

#execute() {
#  . ./jocqey.lib.sh || fail "jocqey.lib.sh not found"
#  #  init_vars
#  #  is_user_valid || fail "Please su to non-root user before running"
#  #  qortal_jar_found || fail "${QORTAL_JAR_FILENAME} not found"
#  #  check_java || fail "Java not valid"
#  #  run_qortal
#  stop_qortal
#}
#
#fail() {
#  echo "FAIL: $*"
#  exit 1
#}
#
#execute "$@"
