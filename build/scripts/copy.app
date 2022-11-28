#! /usr/bin/env bash
BASEDIR=$(dirname "$(dirname "${0}")")
. "${BASEDIR}/scripts/library" "${BASEDIR}"
set -e
show_line
copy_app_to_router
run_reinstalation_on_router
#run_tests
