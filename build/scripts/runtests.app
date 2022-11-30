#! /usr/bin/env bash
BASEDIR=$(dirname "$(dirname "${0}")")
. "${BASEDIR}/scripts/library" "${BASEDIR}"

run_tests
