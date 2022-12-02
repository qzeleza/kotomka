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
set -e

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

#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Сохраняем данные из файлов ./compile/postinst ./compile/postrm в файл манифеста  /compile/Makefile.<ext>
#-------------------------------------------------------------------------------
save_post_blocks(){

    extension=$(echo "${APPS_LANGUAGE}" | tr "[:upper:]" "[:lower:]")
    make_file="${APPS_ROOT}/${APP_NAME}/compile/Makefile.${extension}"
    make_file_tmp="${make_file}.tmp"
    post_inst=$(cat < "${APPS_ROOT}/${APP_NAME}/compile/postinst")
    post_term=$(cat < "${APPS_ROOT}/${APP_NAME}/compile/postrm")


    cat < "${make_file}" \
        | sed '/postinst/,/endef/ { /postinst/n; /endef/n; /postrm/n; /eval/n; {/.*/d;};};' \
        | sed 's/\(.*postinst\)/\1\n\t@POSTINST/; s/\(.*postrm\)/\1\n\t@POSTRM/' \
         > "${make_file_tmp}"

    awk -i inplace -v r="${post_inst}" '{gsub(/@POSTINST/,r)}1' "${make_file_tmp}"
    awk -i inplace -v r="${post_term}" '{gsub(/@POSTRM/,r)}1' "${make_file_tmp}"

    mv -f "${make_file_tmp}" "${make_file}"
    cp "${make_file}" "${APP_MAKE_BUILD_PATH}/Makefile"
}

#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Производим сборку пакета
#-------------------------------------------------------------------------------
do_package_make(){
    deb=${1}
    #rm -f "$(get_ipk_package_file)"
    cd "${APPS_ROOT}/entware/"

    if ! grep -q "${APP_NAME}" "${APPS_ROOT}/entware/.config" ; then

    	make oldconfig <<< m
    	make tools/install ${deb}
    	make toolchain/install ${deb}
    fi

    [[ "${*}" =~ menu|-mc ]] && make menuconfig
    make package/"${APP_NAME}"/compile ${deb}
}
#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Производим первую сборку toolchain в контейнере
# В случае необходимости устанавливаем флаг отладки в YES
#-------------------------------------------------------------------------------

cp -rf "${APPS_ROOT}/${APP_NAME}/code/." "${APP_MAKE_BUILD_PATH}/files"
# Сохраняем данные из файлов ./compile/postinst ./compile/postrm в файл манифеста  /compile/Makefile.<ext>
save_post_blocks

show_line
echo "${PREF}Задействовано ${np} яд. процессора."
echo "${PREF}Режим отладки: $([ "${DEBUG}" = YES ] && echo "ВКЛЮЧЕН" || echo "ОТКЛЮЧЕН")"
echo "${PREF}Makefile успешно импортирован."
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

# проверяем на доступность ip роутера
router_ip=${ROUTER//*@/}
if is_ip_or_host_alive "${router_ip}"; then
    app_tar_name=$(get_ipk_package_file)
    # копируем собранный пакет на роутер
    copy_app_to_router "$(get_ipk_package_file)" "${app_tar_name}"
    run_reinstalation_on_router "${app_tar_name}"
    # Запускаем тесты
    run_tests
else
    echo -e "${RED}${PREF}IP адрес устройства '${router_ip}' - НЕ доступен!${NOCL}"
    echo -e "${RED}${PREF}Установку и тестирование пакета пропускаем!${NOCL}"
fi

show_line

time_end=$(date +%s)
echo "${PREF}Продолжительность сборки составила: $(time_diff "${time_start}" "${time_end}")"
