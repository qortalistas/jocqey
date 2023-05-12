#!/bin/sh

execute() {
  if [ -f ./jocqey.lib.sh ]; then
    . ./jocqey.lib.sh
  else
    load_optional_lib "$@"
  fi
  start_qortal
  #  init_vars
  #  init_colors
  #  is_user_valid || fail "Please su to non-root user before running"
  #  qortal_jar_found || fail "${QORTAL_JAR_FILENAME} not found"
  #  check_java || fail "Java not valid"
  ##  test_qortal
}

load_optional_lib() {
  echo 'load_optional_lib'
  OPERATING_DIR="$(dirname "$(realpath "$0")")"
  optional_lib="${OPERATING_DIR}/optional.jocqey.lib.sh"
  # shellcheck disable=SC1090
  . "${optional_lib}" || fail "Could not source ${optional_lib}"
  optionalyze "$@"
}

fail() {
  echo "FAIL: $*"
  exit 1
}

execute "$@"
