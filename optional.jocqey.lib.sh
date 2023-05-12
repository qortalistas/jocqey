#!/bin/sh

optionalyze() {
  echo 'optionalyze'
  OPERATING_DIR="${OPERATING_DIR:-$(dirname "$(realpath "$0")")}"
  #  OPERATING_DIR="$(dirname "$(realpath "$0")")"
  echo "OPERATING_DIR: ${OPERATING_DIR}"
  main_lib="${OPERATING_DIR}/jocqey.lib.sh"
  find_run_dir || fail "Could not find qortal.jar"
  cd "${QRUN_DIR}" || fail "Could not cd to ${QRUN_DIR}"
  echo "QRUN_DIR: ${QRUN_DIR}"
  # shellcheck disable=SC1090
  . "${main_lib}" || fail "Could not source ${main_lib}"
}

test_optional() {
  echo 'test_optional'
}

find_run_dir() {
  needle='qortal.jar'
  seek_dir="${OPERATING_DIR}}"
  unset QRUN_DIR
  while [ -z "${QRUN_DIR}" ]; do # || [ ! -d "${QRUN_DIR}" ]
    file="${seek_dir}/${needle}"
    if [ -f "${file}" ]; then
      QRUN_DIR="${seek_dir}"
      return 0
    fi
    prev_seek_dir="${seek_dir}"
    seek_dir="$(dirname "${seek_dir}")"
    if [ "${seek_dir}" == "${prev_seek_dir}" ]; then
      echo "Could not find ${needle}"
      return 1
    fi
  done
}
