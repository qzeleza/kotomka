#! /usr/bin/env bash
BASEDIR=$(dirname "$(dirname "${0}")")
. "${BASEDIR}/CONFIG"
set -e
PREF='>> '
#----------------------------------------------------------------------------------------------------------------------
# Получаем имя приложения из названия корневой папки
#----------------------------------------------------------------------------------------------------------------------
APP_NAME=$(pwd | sed "s/.*\\${APPS_ROOT}\/\(.*\).*$/\1/;" | cut -d'/' -f1)

get_version_part(){
	value=${1}
	cat < "${APPS_ROOT}/${APP_NAME}/build/version" | grep "${value}" | cut -d'=' -f2
}

VERSION=$(get_version_part VERSION)
STAGE=$(get_version_part STAGE)
RELEASE=$(get_version_part RELEASE)

#----------------------------------------------------------------------------------------------------------------------
# Получаем имя приложения из названия корневой папки
#----------------------------------------------------------------------------------------------------------------------
APP_NAME=$(pwd | sed "s/.*\\${APPS_ROOT}\/\(.*\).*$/\1/;" | cut -d'/' -f1)
#----------------------------------------------------------------------------------------------------------------------
ext_makefile=$(echo "${APPS_LANGUAGE}" | tr "[:upper:]" "[:lower:]")

MAKE_FILE="../compile/Makefile.${ext_makefile}"
POSTINST_FILE="../compile/postinst"
POSTRM_FILE="../compile/postrm"

APP_ROUTER_DIR="\/opt\\${APPS_ROOT}\/${APP_NAME}"
APP_MAKE_BUILD_PATH=${APPS_ROOT}/entware/package/utils/${APP_NAME}
GITHUB_URL="https:\/\/github.com\/${GITHUB_ACCOUNT_NAME}\/${APP_NAME}"
POST_INST=$(cat < "${POSTINST_FILE}")
POST_TERM=$(cat < "${POSTRM_FILE}")
#if [[ "${ext_makefile}" =~ c|cpp ]] ; then ext="${ext_makefile}"; else ext="sh"; fi
#files_filter=$(echo "${APP_SOURCE_FILES_FILTER}" | sed "s|\(^.*\*\.\).*\(,.*\)$|\1${ext}\2|g")
SOURCE_DIR="\\${APPS_ROOT}\/${APP_NAME}"

sed -e "s/@APP_NAME/${APP_NAME}/g;
s/@VERSION/${VERSION}/g;
s/@APP_ROUTER_DIR/${APP_ROUTER_DIR}/g;
s/@STAGE/${STAGE}/g;
s/@RELEASE/${RELEASE}/g;
s/@LICENCE/${LICENCE}/g;
s/@AUTHOR/${AUTHOR_NAME}/g;
s/@EMAIL/${AUTHOR_EMAIL}/g;
s/@GITHUB/${GITHUB_URL}/g;
s/@CATEGORY/${APP_CATEGORY}/g;
s/@SUBMENU/${APP_SUBMENU}/g;
s/@TITLE/${APP_TITLE}/g;
s/@DEPENDS/${APP_DEPENDS}/g;
s/@SOURCE_DIR/${SOURCE_DIR}/g;" "${MAKE_FILE}" > "${APP_MAKE_BUILD_PATH}/Makefile"

awk -i inplace -v r="${APP_DESCRIPTION}" '{gsub(/@DESCRIPTION/,r)}1' "${APP_MAKE_BUILD_PATH}/Makefile"
awk -i inplace -v r="${POST_INST}" '{gsub(/@POSTINST/,r)}1' "${APP_MAKE_BUILD_PATH}/Makefile"
awk -i inplace -v r="${POST_TERM}" '{gsub(/@POSTRM/,r)}1' "${APP_MAKE_BUILD_PATH}/Makefile"

echo "${PREF}Makefile успешно создан"

