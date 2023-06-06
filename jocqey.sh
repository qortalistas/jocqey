#!/bin/sh

init_lib() {
  debug 'init_lib'
  MONIKER='jocqey'
  #  DO_EXECUTE='true'
  #  if [ $1 = '--no-execute' ]; then
  #    shift
  #    DO_EXECUTE='false'
  #  fi
  QORTAL_JAR_FILENAME='qortal.jar'
  OPERATING_DIR="$(dirname "$(realpath "$0")")"
  #  echo "OPERATING_DIR ${OPERATING_DIR}"
  for dir in "${OPERATING_DIR}" "${OPERATING_DIR}/.." '.'; do
    QORTAL_DIR="$(realpath "${dir}")"
    QORTAL_JAR_FILE="${QORTAL_DIR}/${QORTAL_JAR_FILENAME}"
    [ -f "${QORTAL_JAR_FILE}" ] && break
  done
  [ -f "${QORTAL_JAR_FILE}" ] || fail "Could not find ${QORTAL_JAR_FILENAME} in ${OPERATING_DIR} or ${OPERATING_DIR}/.. or ."
  #  echo "QORTAL_DIR ${QORTAL_DIR}"
  #  echo "QORTAL_JAR_FILE ${QORTAL_JAR_FILE}"
  #  QORTAL_DIR="$(realpath "${QORTAL_DIR}")"
  #  echo "QORTAL_DIR ${QORTAL_DIR}"
  QORTAL_CONFIG_FILENAME="${MONIKER}.config"
  QORTAL_CONFIG_FILE="${QORTAL_DIR}/${QORTAL_CONFIG_FILENAME}"
  #  [ -f "${QORTAL_CONFIG_FILE}" ] || fail "Could not find ${QORTAL_JAR_FILENAME}"
  cd "${QORTAL_DIR}" || fail "Could not cd to ${QORTAL_DIR}"
}

init_vars() {
  XSS_SIZE_DEFAULT=256k
  XMX_SIZE_DEFAULT=128m
  calculate_jvm
  check_config
  source_config
  #  JAVA_EXE_FILE=invalid # for testing
  JAVA_EXE_FILE="${JAVA_EXE_FILE:-$(which java)}"
  MIN_JAVA_VER="${MIN_JAVA_VER:-11.0}"
  #    debug "JAVA_EXE_FILE=${JAVA_EXE_FILE}"
  #### IF JVM_ARGS is set from config, use it, otherwise leave unset:
  [ -n "${JVM_MEMORY_XSS_SIZE}" ] && JVM_MEMORY_XSS="-Xss${JVM_MEMORY_XSS_SIZE}"
  [ -n "${JVM_MEMORY_XMX_SIZE}" ] && JVM_MEMORY_XMX="-Xmx${JVM_MEMORY_XMX_SIZE}"
  #  API_PORT=12391
  API_PORT="${API_PORT:-12391}"

}

calculate_jvm() {
  #### IF these are set, they will be written uncommented to config file:
  XSS_SIZE=256k
  XMX_SIZE=768m
}

check_config() {
  [ -f "${QORTAL_CONFIG_FILE}" ] && return 0
  #### Create config file if it doesn't exist
  #### If XSS_SIZE and XMX_SIZE are set, write uncommented lines:
  [ -n "${XSS_SIZE}" ] && XSS_LINE='' || XSS_LINE='#'
  [ -n "${XMX_SIZE}" ] && XMX_LINE='' || XMX_LINE='#'
  XSS_SIZE="${XSS_SIZE:-"${XSS_SIZE_DEFAULT}"}"
  XMX_SIZE="${XMX_SIZE:-"${XMX_SIZE_DEFAULT}"}"
  XSS_LINE="${XSS_LINE}JVM_MEMORY_XSS_SIZE=${XSS_SIZE}"
  XMX_LINE="${XMX_LINE}JVM_MEMORY_XMX_SIZE=${XMX_SIZE}"

  cat <<-EOF >"${QORTAL_CONFIG_FILE}"
## ${MONIKER} config file.
# Limits Java JVM stack size and maximum heap usage.
# Comment out for bigger systems, e.g. non-routers
# or when API documentation is enabled
${XSS_LINE}
${XMX_LINE}

#JAVA_EXE_FILE=custom_path_to_java
#MIN_JAVA_VER=11.0
#API_PORT=12391 #Must correspond to apiPort in settings.json
#MULTI_INSTANCE_MODE=true
#ALLOW_ROOT_USER=true
#DEBUG_MODE=true

EOF
}

source_config() {
  # shellcheck disable=SC1090
  . "${QORTAL_CONFIG_FILE}" || fail "Could not source ${QORTAL_CONFIG_FILENAME}"
}

init_from_config() {
  if [ "${DEBUG_MODE}" != 'true' ]; then
    # If not in debug mode, create an inactive debug function.
    debug() {
      :
    }
  fi
}

is_multi_instance_mode() {
  [ "${MULTI_INSTANCE_MODE}" = 'true' ]
}

preparyze() {
  init_vars
  init_from_config
  init_colors
  debug "Preparing Qortal..."
  is_user_valid || fail "Please su to non-root user before running"
  #  qortal_jar_found || fail "${QORTAL_JAR_FILENAME} not found"
  check_java || fail "Java not valid"
}

start_qortal() {
  debug 'start_qortal'
#  preparyze
  message "Starting Qortal..."
  ## TODO: check if qortal is already running
  is_pid_running '--strict' && fail "This Qortal is already running."
  if ! is_multi_instance_mode; then
    is_pid_running '--lenient' && fail "Some other Qortal is already running (Not in local pid-file)"
  fi
  is_api_running && fail "Some Qortal is already running on 'our' port ${API_PORT}"
  run_qortal
  monitor_startup
}

stop_qortal() {
#  preparyze
  message "Stopping Qortal..."
  unrun_qortal "$@"
}

run_qortal() {
  nohup nice -n 19 "${JAVA_EXE_FILE}" \
    -Djava.net.preferIPv4Stack=false \
    "${JVM_MEMORY_XSS}" \
    "${JVM_MEMORY_XMX}" \
    -jar "${QORTAL_JAR_FILENAME}" \
    1>run.log 2>&1 &
  # Save backgrounded process's PID
  erase_pid
  echo $! >run.pid
  success qortal running as pid $!
}

unrun_qortal() {
  #  debug "unrun_qortal"
  #### Split into subfunctions for easier (future) development.
  _read_apikey() {
    # Locate the API key if it exists
    apikey=$(cat apikey.txt)
    success=0
  }
  #  _locate_any_qortal_pid() {
  #    # Attempt to locate ANY qortal process ID if we don't have one
  #    if [ -z "${pid}" ]; then
  #      pid=$(ps aux | grep '[q]ortal.jar' | head -n 1 | awk '{print $2}')
  #      has_fetched_pid=$?
  #    fi
  #    return ${has_fetched_pid}
  #  }

  _testnet_port() {
    # Swap out the API port if the --testnet (or -t) argument is specified
    for param in "$@"; do
      case $param in
      -t | --testnet*)
        API_PORT=62391
        break
        ;;
      esac
    done
  }
  _stop_via_api() {
    # Try and stop via the API
    if [ -n "$apikey" ]; then
      message "Stopping Qortal via API …"
      if curl --url "http://localhost:${API_PORT}/admin/stop?apiKey=$apikey" 1>/dev/null 2>&1; then
        success=1
      fi
    fi
  }
  _kill_by_sigterm() {
    # Try to kill process with SIGTERM
    if [ "$success" -ne 1 ] && [ -n "$pid" ]; then
      message "Stopping Qortal via kill process $pid …"
      if kill -15 "${pid}"; then
        success=1
      fi
    fi
  }
  _no_success_exit() {
    # Warn and exit if still no success
    if [ "$success" -ne 1 ]; then
      if [ -n "$pid" ]; then
        fail "Stop command failed - not running with process id ${pid}?"
        #      echo "${red}Stop command failed - not running with process id ${pid}?${normal}"
      else
        fail "Stop command failed - not running?"
      fi
      #    exit 1
    fi
  }
  _monitor_ending() {
    if [ "$success" -eq 1 ]; then
      message "Qortal node should be shutting down"
      if is_pid_fetched; then
        message -n "Monitoring for Qortal node to end: "
        while is_pid_running; do
          message -n .
          sleep 1
        done
        echo
        success "Qortal ended gracefully"
        erase_pid
      fi
    fi
  }

  #  read_pid
  #  locate_any_qortal_pid
  obtain_pid
  _testnet_port "$@"
  _read_apikey
  _stop_via_api
  _kill_by_sigterm
  _no_success_exit
  _monitor_ending

  exit 0
}

erase_pid() {
  rm -f run.pid
}

is_pid_fetched() {
  [ "${has_fetched_pid}" -eq 0 ]
}

read_pid() {
  unset pid
  # Read the pid file if possible
  read pid 2>/dev/null <run.pid
  has_fetched_pid=$?
  return ${has_fetched_pid}
}

locate_any_qortal_pid() {
  # Attempt to locate ANY qortal process ID if we don't have one
  #  if [ -z "${pid}" ]; then
  # shellcheck disable=SC2009
  pid=$(ps aux | grep '[q]ortal.jar' | head -n 1 | awk '{print $2}')
  has_fetched_pid=$?
  #  fi
  return ${has_fetched_pid}
}

# shellcheck disable=SC2120
obtain_pid() {
  mode='lenient'
  if [ "$1" = '--strict' ]; then
    shift
    mode='strict'
  elif [ "$1" = '--lenient' ]; then
    shift
    mode='lenient'
  elif is_multi_instance_mode; then
    mode='strict'
  fi
  read_pid
  if [ mode = 'lenient' ]; then
    locate_any_qortal_pid
  fi
  return ${has_fetched_pid}
}

# shellcheck disable=SC2120
is_pid_running() {
  #  obtain_func='obtain_pid'
  #  if [ "$1" = '--strict' ]; then
  #    shift
  #    obtain_func='read_pid'
  #  fi
  #  #set pid to arg1 if not already set:
  #  pid="${pid:-$1}"
  #  if [ -z "${pid}" ]; then
  #    # obtain pid if not already set:
  #    "${obtain_func}"
  #  fi
  obtain_pid "$@"
  is_pid_fetched || return "${has_fetched_pid}"
  s=$(ps -p "${pid}" -o stat=) && [ "$s" ] && [ "$s" != 'Z' ]
}

is_api_running() {
  #  debug "--url http://localhost:${API_PORT}/admin/status"
  API_STATUS=$(curl --fail --silent --url "http://localhost:${API_PORT}/admin/status")
  #  API_STATUS=$(curl --url "http://localhost:${API_PORT}/admin/status" 2>/dev/null)
  #  API_STATUS=$(curl --fail --url "http://localhost:${API_PORT}/admin/status" 2>/dev/null)
  #  curl --url "http://localhost:${API_PORT}/admin/status" 1>/dev/null 2>&1
  #  # Try and stop via the API
  #  if [ -n "$apikey" ]; then
  #    message "Stopping Qortal via API …"
  #    if curl --url "http://localhost:${API_PORT}/admin/stop?apiKey=$apikey" 1>/dev/null 2>&1; then
  #      success=1
  #    fi
  #  fi
}

monitor_startup() {
  # Monitor for Qortal node to start
  message -n "Monitoring for Qortal node to start: "
  message -n "Monitoring for pid-file to appear: "
  set_timeout 5
  while ! read_pid && ! timeout_reached; do
    message -n .
    sleep 0.01
  done
  echo
  read_pid || startup_failed "Pid-file did not appear."
  debug "Pid file appeared."
  is_pid_running || startup_failed "Pid is not running."
  ####
  message -n 'Monitoring log for "API started" ... '
  LOG_FILE="${QORTAL_DIR}/log/qortal.log"
  #  https://superuser.com/a/900134
  (tail -f --pid="${pid}" -n0 "${LOG_FILE}" &) | grep -q "Starting API"
  # shellcheck disable=SC2181
  if [ $? -ne 0 ]; then
    echo "MONITORED FAIL: API started" >>"${LOG_FILE}"
    startup_failed "API did not start."
  else
    echo "MONITORED SUCCES: API started" >>"${LOG_FILE}"
    success "API started"
  fi
  ####
  message -n 'Monitoring api for status: '
  set_timeout 15
  while ! is_api_running && ! timeout_reached; do
    message -n .
    sleep 0.1
  done
  echo
  if is_api_running; then
    success "API is running"
    debug "API_STATUS: ${API_STATUS}"
  else
    debug "API_STATUS: ${API_STATUS}"
    startup_failed "API is not running."
  fi
}

set_timeout() {
  dur="${1:-5}"
  TIMEOUT_END_TIME=$(($(date +%s) + dur))
}

timeout_reached() {
  [ "$(date +%s)" -ge "${TIMEOUT_END_TIME}" ]
}

startup_failed() {
  erase_pid
  fail "Startup failed: $1"
}

is_user_valid() {
  [ "${ALLOW_ROOT_USER}" = 'true' ] && return 0
  [ "$(id -u)" -ne 0 ]
}

qortal_jar_found() {
  # This concept inherited from original script is abandoned,
  #  as we're now using the location of qortal.jar to determine the qortal-dir.
  [ -e ${QORTAL_JAR_FILENAME} ] && return 0
  for file in target/qortal*.jar; do
    if [ -f "${file}" ]; then
      message "Copying Maven-built Qortal JAR to correct pathname"
      cp -a "${file}" "${QORTAL_JAR_FILENAME}"
      break
    fi
  done
  [ -e ${QORTAL_JAR_FILENAME} ]
}

check_java() {
  if command -v "${JAVA_EXE_FILE}" >/dev/null 2>&1; then
    # Example: openjdk version "11.0.6" 2020-01-14
    version=$("${JAVA_EXE_FILE}" -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1,2)
    #    debug "version=${version}"
    if echo "${version}" "${MIN_JAVA_VER}" | awk '{ if ($2 > 0 && $1 >= $2) exit 0; else exit 1}'; then
      success 'Passed Java version check'
    else
      error "Please upgrade your Java to version ${MIN_JAVA_VER} or greater"
    fi
  else
    error "Java is not available, please install Java ${MIN_JAVA_VER} or greater"
  fi
  #  return 0
}

message() {
  print_color "${yellow}" "$@"
}

debug() {
  print_color "${grey}" "$@"
}

success() {
  print_color "${green}" -p 'OK: ' "$@"
  return 0
}

error() {
  print_color "${orange}" -p 'ERROR: ' "$@"
  return 1
}

fail() {
  print_color "${red}" -p 'FAIL: ' "$@"
  exit 1
}

print_color() {
  color="$1"
  shift
  if [ "$1" = '-p' ]; then
    shift
    pretxt="$1"
    shift
  fi
  if [ "$1" = '-n' ]; then
    shift
    printf "${color}%s%s${normal}" "${pretxt}" "$*"
  else
    printf "${color}%s%s${normal}\n" "${pretxt}" "$*"
  fi
  unset pretxt
}

init_colors() {
  if [ -t 1 ]; then
    ncolors=$(tput colors)
    if [ -n "${ncolors}" ] && [ "${ncolors}" -ge 8 ]; then
      if normal="$(tput sgr0)"; then
        # use terminfo names
        red="$(tput setaf 160)"
        green="$(tput setaf 10)"
        yellow="$(tput setaf 11)"
        #        blue="$(tput setaf 12)"
        grey="$(tput setaf 7)"
        orange="$(tput setaf 166)"
      else
        # use termcap names for FreeBSD compat
        normal="$(tput me)"
        red="$(tput AF 160)"
        green="$(tput AF 10)"
        yellow="$(tput AF 11)"
        #        blue="$(tput AF 12)"
        grey="$(tput AF 7)"
        orange="$(tput AF 166)"
      fi
    fi
  fi
}

test_colors() {
  #### requires bash.
  message "test_colors"
  for color in red green yellow blue grey orange; do
    # shellcheck disable=SC2039
    print_color "${!color}" "${color}"
  done
  # for i in 1 to 255; do
  #  for i in {1..255}; do
  #    echo "${i}" $(tput AF "${i}")
  ##    print_color "${i}" "${i}"
  #  done
}

test_qortal() {
  preparyze
  message "test_qortal"

  for i in 1 2 3 4; do
    debug -n "$i"
  done
  echo

  for i in 1 2 3 4; do
    success -n "$i "
  done
  echo

  test_colors
  debug "debug"
  message "message"
  error "error"
  fail "fail"
}

####

execute_arguments() {
  debug "execute_arguments $*"
  # if no arguments, then exit:
  if [ $# -eq 0 ]; then
    error "No arguments specified"
    #    usage
    exit 1
  fi
  command="$1"
  shift
  case "${command}" in
  start)
    #    start_qortal "$@"
    func='start_qortal'
    ;;
  stop)
    #    stop_qortal "$@"
    func='stop_qortal'
    ;;
    #  restart)
    #    restart_qortal "$@"
    #    ;;
    #  status)
    #    status_qortal "$@"
    #    ;;
  test)
    #    test_qortal "$@"
    func='test_qortal'
    ;;
  *)
    error "Unknown command: ${command}"
    usage
    exit 1
    ;;
  esac
  [ -z "${func}" ] && fail "func is empty (Should not happen)"
  preparyze
  "${func}" "$@"
}

init_lib "$@"
if [ "${NO_EXECUTE}" != 'true' ]; then
  execute_arguments "$@"
fi

#####################
