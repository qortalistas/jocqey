#!/bin/sh

execute() {
  printf "\n%s\n" '-----------------------------------------------------------'
  load_lib
  test_qortal
}

load_lib() {
  MONIKER='jocqey'
  OPERATING_DIR="$(dirname "$(realpath "$0")")"
  for MONIKER_DIR in "${OPERATING_DIR}" "${OPERATING_DIR}/.." \
    "${OPERATING_DIR}/${MONIKER}" "${OPERATING_DIR}/../.." '.'; do
    # shellcheck disable=SC1090
    [ -f "${MONIKER_DIR}/${MONIKER}.sh" ] && NO_EXECUTE='true' . "${MONIKER_DIR}/${MONIKER}.sh" && return 0
  done
  echo "Could not source ${MONIKER}.sh"
  exit 1
}

execute "$@"
