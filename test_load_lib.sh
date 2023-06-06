#!/bin/sh

execute() {
  MONIKER='jocqey'
  printf "\n%s\n" '-----------------------------------------------------------'
  load_lib
  test_qortal
}

load_lib() {
  #  echo "load_lib ${MONIKER}"
  OPERATING_DIR="$(dirname "$(realpath "$0")")"
  #  echo "OPERATING_DIR ${OPERATING_DIR}"
  for MONIKER_DIR in "${OPERATING_DIR}" "${OPERATING_DIR}/.." \
    "${OPERATING_DIR}/${MONIKER}" "${OPERATING_DIR}/../.." '.'; do
    # shellcheck disable=SC1090
    NO_EXECUTE='true' . "${MONIKER_DIR}/${MONIKER}.sh" && return 0
  done
  echo "Could not source ${MONIKER}.sh"
  exit 1
}

#fail() {
#  echo "FAIL: $*"
#  exit 1
#}

execute "$@"
