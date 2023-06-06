#!/bin/sh

execute() {
  printf "\n%s\n" '-----------------------------------------------------------'
  /opt/projects/qortal_top/qortal_asusi7/jocqey/jocqey.sh test
}

execute "$@"
