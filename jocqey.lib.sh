#!/bin/sh

init_vars() {
  QORTAL_JAR_FILENAME='qortal.jar'
  QORTAL_CONFIG_FILENAME='jocqey.config'
  XSS_SIZE_DEFAULT=256k
  XMX_SIZE_DEFAULT=128m
  calculate_jvm
  check_config
  source_config
  #  JAVA_EXE_FILE=invalid # for testing
  JAVA_EXE_FILE="${JAVA_EXE_FILE:-$(which java)}"
  MIN_JAVA_VER="${MIN_JAVA_VER:-11.0}"
  ##   Limits Java JVM stack size and maximum heap usage.
  ##   Comment out for bigger systems, e.g. non-routers
  ##   or when API documentation is enabled
  ##   JVM_MEMORY_ARGS="-Xss256k -Xmx128m"
  #    debug "JAVA_EXE_FILE=${JAVA_EXE_FILE}"
  #### IF JVM_ARGS is set from config, use it, otherwise leave unset:
  [ -n "${JVM_MEMORY_XSS_SIZE}" ] && JVM_MEMORY_XSS="-Xss${JVM_MEMORY_XSS_SIZE}"
  [ -n "${JVM_MEMORY_XMX_SIZE}" ] && JVM_MEMORY_XMX="-Xmx${JVM_MEMORY_XMX_SIZE}"
}

calculate_jvm() {
  #### IF these are set, they will be written uncommented to config file:
  XSS_SIZE=256k
  XMX_SIZE=768m
}

check_config() {
  [ -f "${QORTAL_CONFIG_FILENAME}" ] && return 0
  #### Create config file if it doesn't exist
  #### If XSS_SIZE and XMX_SIZE are set, write uncommented lines:
  [ -n "${XSS_SIZE}" ] && XSS_LINE='' || XSS_LINE='#'
  [ -n "${XMX_SIZE}" ] && XMX_LINE='' || XMX_LINE='#'
  XSS_SIZE="${XSS_SIZE:-"${XSS_SIZE_DEFAULT}"}"
  XMX_SIZE="${XMX_SIZE:-"${XMX_SIZE_DEFAULT}"}"
  XSS_LINE="${XSS_LINE}JVM_MEMORY_XSS_SIZE=${XSS_SIZE}"
  XMX_LINE="${XMX_LINE}JVM_MEMORY_XMX_SIZE=${XMX_SIZE}"

  cat <<-EOF >"${QORTAL_CONFIG_FILENAME}"
## jocqey config file.
# Limits Java JVM stack size and maximum heap usage.
# Comment out for bigger systems, e.g. non-routers
# or when API documentation is enabled
${XSS_LINE}
${XMX_LINE}

#JAVA_EXE_FILE=custom_path_to_java
#ALLOW_ROOT_USER=true
#MIN_JAVA_VER=11.0

EOF
}

source_config() {
  # shellcheck disable=SC1090
  . ./"${QORTAL_CONFIG_FILENAME}"
}

preparyze() {
  init_vars
  init_colors
  debug "Preparing Qortal..."
  is_user_valid || fail "Please su to non-root user before running"
  qortal_jar_found || fail "${QORTAL_JAR_FILENAME} not found"
  check_java || fail "Java not valid"
}

start_qortal() {
  preparyze
  message "Starting Qortal..."
  #  init_vars
  #  is_user_valid || fail "Please su to non-root user before running"
  #  qortal_jar_found || fail "${QORTAL_JAR_FILENAME} not found"
  #  check_java || fail "Java not valid"
  ## TODO: check if qortal is already running
  run_qortal
}

stop_qortal() {
  preparyze
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
  echo $! >run.pid
  success qortal running as pid $!
}

is_user_valid() {
  [ "${ALLOW_ROOT_USER}" = 'true' ] && return 0
  [ "$(id -u)" -ne 0 ]
}

#is_user_root() {
#  [ "$(id -u)" -eq 0 ]
#}

qortal_jar_found() {
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

#message() {
#  print_color '1;33' "$*"
#}
#
#debug() {
#  print_color '1;37' "$*"
#}
#
#error() {
#  print_color '34' "ERROR: $*"
#  return 1
#}
#
#fail() {
#  print_color '31' "FAIL: $*"
#  exit 1
#}
#
#x_print_color() {
#  color_code="${1:-0}"
#  shift
#  #  echo "\e[${color_code}m$*\e[0m"
#  echo -e "\e[${color_code}m$*\e[0m" # In POSIX sh, echo flags are undefined.
#}

message() {
  print_color "${yellow}" "$@"
}

debug() {
  print_color "${grey}" "$@"
}

success() {
  print_color "${green}" 'OK: ' "$@"
  return 0
}

error() {
  print_color "${orange}" 'ERROR: ' "$@"
  return 1
}

fail() {
  print_color "${red}" 'FAIL: ' "$@"
  exit 1
}

print_color() {
  color="$1"
  shift
  #todo posixfy nflag
  # In POSIX sh, echo flags are undefined.
  if [ "$1" = '-n' ]; then
    shift
    echo -n "${color}$*${normal}"
  else
    echo "${color}$*${normal}"
  fi
}

init_colors() {
  if [ -t 1 ]; then
    ncolors=$(tput colors)
    if [ -n "${ncolors}" ] && [ "${ncolors}" -ge 8 ]; then
      if normal="$(tput sgr0)"; then
        # use terminfo names
        #        echo "terminfo names"
        red="$(tput setaf 160)"
        green="$(tput setaf 10)"
        yellow="$(tput setaf 11)"
        blue="$(tput setaf 12)"
        grey="$(tput setaf 7)"
        orange="$(tput setaf 166)"

        #        for i in {1..255}; do
        #          echo "$(tput setaf "${i}") ${i} $(tput sgr0)"
        #          #    print_color "${i}" "${i}"
        #        done

      else
        #        echo "termcap names"
        # use termcap names for FreeBSD compat
        normal="$(tput me)"
        red="$(tput AF 160)"
        green="$(tput AF 10)"
        yellow="$(tput AF 11)"
        blue="$(tput AF 12)"
        grey="$(tput AF 7)"
        orange="$(tput AF 166)"
      fi
    fi
  fi
}

test_colors() {
  message "test_colors"
  for color in red green yellow blue grey orange; do
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
  test_colors
  debug "debug"
  message "message"
  error "error"
  fail "fail"
}

#####################

unrun_qortal() {
  #  debug "unrun_qortal"

  # Track the pid if we can find it
  read pid 2>/dev/null <run.pid
  is_pid_valid=$?

  # Swap out the API port if the --testnet (or -t) argument is specified
  api_port=12391
  for param in "$@"; do
    case $param in
    -t | --testnet*)
      api_port=62391
      break
      ;;
    esac
  done
  #  if [[ "$@" = *"--testnet"* ]] || [[ "$@" = *"-t"* ]]; then
  #    api_port=62391
  #  fi

  # Attempt to locate the process ID if we don't have one
  if [ -z "${pid}" ]; then
    pid=$(ps aux | grep '[q]ortal.jar' | head -n 1 | awk '{print $2}')
    is_pid_valid=$?
  fi

  # Locate the API key if it exists
  apikey=$(cat apikey.txt)
  success=0

  # Try and stop via the API
  if [ -n "$apikey" ]; then
    message "Stopping Qortal via API …"
    if curl --url "http://localhost:${api_port}/admin/stop?apiKey=$apikey" 1>/dev/null 2>&1; then
      success=1
    fi
  fi

  # Try to kill process with SIGTERM
  if [ "$success" -ne 1 ] && [ -n "$pid" ]; then
    message "Stopping Qortal via kill process $pid …"
    if kill -15 "${pid}"; then
      success=1
    fi
  fi

  # Warn and exit if still no success
  if [ "$success" -ne 1 ]; then
    if [ -n "$pid" ]; then
      fail "Stop command failed - not running with process id ${pid}?"
      #      echo "${red}Stop command failed - not running with process id ${pid}?${normal}"
    else
      fail "Stop command failed - not running?"
      #      echo "${red}Stop command failed - not running?${normal}"
    fi
    #    exit 1
  fi

  if [ "$success" -eq 1 ]; then
    message "Qortal node should be shutting down"
    if [ "${is_pid_valid}" -eq 0 ]; then
      message -n "Monitoring for Qortal node to end: "
      #      while s=$(ps -p $pid -o stat=) && [[ "$s" && "$s" != 'Z' ]]; do
      while s=$(ps -p "$pid" -o stat=) && [ "$s" ] && [ "$s" != 'Z' ]; do
        message -n .
        sleep 1
      done
      echo
      success "Qortal ended gracefully"
      #      echo "${green}Qortal ended gracefully${normal}"
      rm -f run.pid
    fi
  fi

  exit 0
}

################################################################################

originalish_stop_qortal() {
  message "Stopping Qortal..."
  # Check for color support
  if [ -t 1 ]; then
    ncolors=$(tput colors)
    if [ -n "${ncolors}" ] && [ "${ncolors}" -ge 8 ]; then
      if normal="$(tput sgr0)"; then
        # use terminfo names
        red="$(tput setaf 1)"
        green="$(tput setaf 2)"
      else
        # use termcap names for FreeBSD compat
        normal="$(tput me)"
        red="$(tput AF 1)"
        green="$(tput AF 2)"
      fi
    fi
  fi

  # Track the pid if we can find it
  read pid 2>/dev/null <run.pid
  is_pid_valid=$?

  # Swap out the API port if the --testnet (or -t) argument is specified
  api_port=12391
  for param in "$@"; do
    case $param in
    -t | --testnet*)
      api_port=62391
      break
      ;;
    esac
  done
  #  if [[ "$@" = *"--testnet"* ]] || [[ "$@" = *"-t"* ]]; then
  #    api_port=62391
  #  fi

  # Attempt to locate the process ID if we don't have one
  if [ -z "${pid}" ]; then
    pid=$(ps aux | grep '[q]ortal.jar' | head -n 1 | awk '{print $2}')
    is_pid_valid=$?
  fi

  # Locate the API key if it exists
  apikey=$(cat apikey.txt)
  success=0

  # Try and stop via the API
  if [ -n "$apikey" ]; then
    echo "Stopping Qortal via API..."
    if curl --url "http://localhost:${api_port}/admin/stop?apiKey=$apikey" 1>/dev/null 2>&1; then
      success=1
    fi
  fi

  # Try to kill process with SIGTERM
  if [ "$success" -ne 1 ] && [ -n "$pid" ]; then
    echo "Stopping Qortal process $pid..."
    if kill -15 "${pid}"; then
      success=1
    fi
  fi

  # Warn and exit if still no success
  if [ "$success" -ne 1 ]; then
    if [ -n "$pid" ]; then
      echo "${red}Stop command failed - not running with process id ${pid}?${normal}"
    else
      echo "${red}Stop command failed - not running?${normal}"
    fi
    exit 1
  fi

  if [ "$success" -eq 1 ]; then
    echo "Qortal node should be shutting down"
    if [ "${is_pid_valid}" -eq 0 ]; then
      echo -n "Monitoring for Qortal node to end"
      #      while s=$(ps -p $pid -o stat=) && [[ "$s" && "$s" != 'Z' ]]; do
      while s=$(ps -p "$pid" -o stat=) && [ "$s" ] && [ "$s" != 'Z' ]; do
        echo -n .
        sleep 1
      done
      echo
      echo "${green}Qortal ended gracefully${normal}"
      rm -f run.pid
    fi
  fi

  exit 0

}
################################################################################
#shelly() {
#  echo "execute() $*"
#  _ps=$(ps -p $$)
#  echo "_ps=${_ps}"
#  #  echo $0
#  readlink /proc/$$/exe
#  #  env
#  #  echo "1SHELL=${SHELL}"
#  echo "POSIXLY_CORRECT=${POSIXLY_CORRECT}"
#
#  #unset SHELL
#  kurt=1
#  [ -n "${kurt}" ] && echo "kurt=${kurt}"
#  [[ -n "${kurt}" ]] && echo "kurt=${kurt}"
#  #  echo ${BASH_VERSION}
#}
