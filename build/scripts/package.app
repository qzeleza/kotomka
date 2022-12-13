#! /usr/bin/env bash

#-------------------------------------------------------------------------------
# Copyright (c) 2022.
# Все права защищены.
#
# Автор: Zeleza
# Email: mail @ zeleza точка ru
#
# Все права защищены.
#
# Продукт распространяется под лицензией Apache License 2.0
# Текст лицензии и его основные положения изложены на русском
# и английском языках, по ссылкам ниже:
#
# https://github.com/qzeleza/kotomka/blob/main/LICENCE.ru
# https://github.com/qzeleza/kotomka/blob/main/LICENCE.en
#
# Перед копированием, использованием, передачей или изменением
# любой части настоящего кода обязательным условием является
# прочтение и неукоснительное соблюдение всех, без исключения,
# статей, лицензии Apache License 2.0 по вышеуказанным ссылкам.
#-------------------------------------------------------------------------------

PREF='>> '
set -ex

BASEDIR=$(dirname "$(dirname "${0}")")
. "${BASEDIR}/scripts/library"
DEBUG=NO

if echo "${DEBUG}" | grep -qE 'YES|yes'; then
    deb="-j1 V=sc";
    np=1;
else
    deb="-j$(nproc)";
    np="$(nproc)";
fi


APP_NAME=$(pwd | sed "s/.*\\${APPS_ROOT}\/\(.*\).*$/\1/;" | cut -d'/' -f1)
APP_MAKE_BUILD_PATH=${APPS_ROOT}/entware/package/utils/${APP_NAME}
BUILD_CONFIG="${APPS_ROOT}/entware/.config"
PREV_PKGARCH=''
#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Сохраняем данные из файлов ./compile/postinst ./compile/postrm в файл манифеста  /compile/Makefile.<ext>
#-------------------------------------------------------------------------------
create_makefile(){

    extension=$(echo "${APPS_LANGUAGE}" | tr "[:upper:]" "[:lower:]")
    make_file="${APPS_ROOT}/${APP_NAME}/compile/Makefile.${extension}"
    PREV_PKGARCH=$(cat < "${make_file}" | grep PKGARCH | sed 's/PKGARCH:=//' | tr -d ' ')

    # копируем данные кода в папку для компиляции
    cp -rf "${APPS_ROOT}/${APP_NAME}/code/." "${APP_MAKE_BUILD_PATH}/files"

    if [ -f "${APPS_ROOT}/${APP_NAME}/compile/postinst" ] ; then
        post_inst=$(cat < "${APPS_ROOT}/${APP_NAME}/compile/postinst")
        post_inst=$(printf "%s\n%s\n%s\n" "define Package/${APP_NAME}/postinst" "${post_inst}" "endef")
        awk -i inplace -v r="${post_inst}" '{gsub(/@POSTINST/,r)}1' "${make_file}"
    else
        sed -i 's/@POSTINST//;' "${make_file}"
    fi

    if [ -f "${APPS_ROOT}/${APP_NAME}/compile/postrm" ] ; then
        post_term=$(cat < "${APPS_ROOT}/${APP_NAME}/compile/postrm")
        post_term=$(printf "%s\n%s\n%s\n" "define Package/${APP_NAME}/postrm" "${post_term}" "endef")
        awk -i inplace -v r="${post_term}" '{gsub(/@POSTRM/,r)}1' "${make_file}"
    else
        sed -i 's/@POSTRM//;' "${make_file}"
    fi


    sed -i "s|\(PKGARCH:=\).*|\1${ARCH_BUILD}|g;"  "${make_file}"
    cp "${make_file}" "${APP_MAKE_BUILD_PATH}/Makefile"

    # в случае отсутствия .config копируем его
    if [ "${PREV_PKGARCH}" != "${ARCH_BUILD}" ] || ! [ -f "${BUILD_CONFIG}" ]; then
#        rm -f "${BUILD_CONFIG}.old" /apps/entware/tmp/.config
        cd "${APPS_ROOT}/entware/"
        make distclean
        cp "$(ls ${APPS_ROOT}/entware/configs/${ARCH_BUILD}.config)" "${BUILD_CONFIG}"
        cat < "${BUILD_CONFIG}" | grep "$(echo ${ARCH_BUILD} | tr '-' '_')"
    fi
}

#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Производим сборку пакета
#-------------------------------------------------------------------------------
do_package_make(){
    deb=${1}
    cd "${APPS_ROOT}/entware/"

    if ! grep -q "${APP_NAME}" "${BUILD_CONFIG}" ; then
    	make oldconfig <<< m
    	make tools/install ${deb}
    	make toolchain/install ${deb}
        mv -f "${BUILD_CONFIG}" "${APPS_ROOT}/${APP_NAME}/compile/${ARCH_BUILD}.config"
        rm "${BUILD_CONFIG}.old"
    fi
    make package/"${APP_NAME}"/compile ${deb}
}


#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Производим первую сборку toolchain в контейнере
# В случае необходимости устанавливаем флаг отладки в YES
#-------------------------------------------------------------------------------



# Сохраняем данные из файлов ./compile/postinst ./compile/postrm в файл манифеста  /compile/Makefile.<ext>
create_makefile

show_line
echo "${PREF}Задействовано ${np} яд. процессора."
echo "${PREF}Режим отладки: $([ "${DEBUG}" = YES ] && echo "ВКЛЮЧЕН" || echo "ОТКЛЮЧЕН")"
echo "${PREF}Makefile для ${ARCH_BUILD} успешно импортирован."
echo "${PREF}Собираем пакет ${APP_NAME} вер. ${FULL_VERSION}"
show_line
echo "${PREF}Сборка запущена: $(zdump EST-3)"; show_line

time_start=$(date +%s)
# Собираем пакет

do_package_make "${deb}"

# копируем собранный пакет в папку где хранятся все сборки
[ -d "${APPS_ROOT}/${APP_NAME}/ipk" ] || mkdir -p "${APPS_ROOT}/${APP_NAME}/ipk"
cp "$(get_ipk_package_file)" "${APPS_ROOT}/${APP_NAME}/ipk"

show_line
copy_and_install_package "ask";
show_line

time_end=$(date +%s)
echo "${PREF}Продолжительность сборки составила: $(time_diff "${time_start}" "${time_end}")"

