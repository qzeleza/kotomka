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
set -x

BASEDIR=$(dirname "$(dirname "${0}")")
. "${BASEDIR}/apps/library" "$(dirname "${BASEDIR}")"
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
COMPILE_PATH=${APPS_ROOT}/${APP_NAME}/${ROOT_PATH//.\//}/${COMPILE_NAME}
BUILD_CONFIG="${APPS_ROOT}/entware/.config"
PREV_PKGARCH=''
#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Проверяем
#-------------------------------------------------------------------------------
check_arch(){

	configs_path="${COMPILE_PATH}/configs"
    mkdir_when_not "${configs_path}"

    if [ "${PREV_PKGARCH}" = "${ARCH_BUILD}" ]; then
        [ -f "${configs_path}/${ARCH_BUILD}.config" ] &&
            cp -f  "${configs_path}/${ARCH_BUILD}.config" "${BUILD_CONFIG}"
    else
        # в случае отсутствия .config копируем его
        if ! [ -f "${BUILD_CONFIG}" ]; then
            cd "${APPS_ROOT}/entware/"
            [ "${PREV_PKGARCH}" = '@PKGARCH' ] || make dirclean
            cp "$(ls "${APPS_ROOT}"/entware/configs/"${ARCH_BUILD}".config)" "${BUILD_CONFIG}"
        fi
    fi
}

#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Создаем секцию в Packages/* в файле манифеста /${COMPILE_NAME}/Makefile
#-------------------------------------------------------------------------------
create_package_section(){

    section_name=${1}
    make_file="${2}"
    section_name_caps=$(echo "${section_name}" | tr "[:lower:]" "[:upper:]")
    section_conf=$(get_config_value "SECTION_${section_name_caps}")

    if [ -n "${section_conf}" ]; then
        if [ -f "${COMPILE_PATH}/${DEV_MANIFEST_DIR_NAME}/${section_name}" ] ; then
            section_text=$(cat < "${COMPILE_PATH}/${DEV_MANIFEST_DIR_NAME}/${section_name}")
            if [ -n "${section_text}" ] ; then
				section_text=$(printf "%s\n%s\n%s\n" "define Package/${APP_NAME}/${section_name}" "${section_text}" "endef")
				awk -i inplace -v r="${section_text}" "{gsub(/@${section_name_caps}/,r)}1" "${make_file}"
			else
				sed -i "s/@${section_name_caps}//;" "${make_file}"
			fi
        else
            sed -i "s/@${section_name_caps}//;" "${make_file}"
        fi
    fi

}


#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
#  Создаем секцию Package/project/install в случае, если
#  в папке opt и ниже по ее структуре есть файлы
#  для файла манифеста
#-------------------------------------------------------------------------------
#make_install_section_for_opt(){
#
#	install_section=""
#	install_section=$(printf "%s\n%s\n" "${install_section}" "\$(INSTALL_DIR) \$(1)/opt/bin" )
#	install_section=$(printf "%s\n%s\n" "${install_section}" "\$(INSTALL_BIN) \$(PKG_BUILD_DIR)/${APP_NAME} \$(1)/opt/bin/")
#	opt_founded_files=$(find "${OPT_PATH}" -type f)
#	if [ -n "${opt_founded_files}" ]; then
#		for opt_file in $(find "${OPT_PATH}" -type f); do
#			file_path=$(dirname "${opt_file}")
#			$(PKG_BUILD_DIR)/@APP_NAME $(1)/opt/bin/
#			install_section=$(printf "%s\n%s\n" "${install_section}" "\$(INSTALL_DIR) \$(1)${file_path}")
#			install_section=$(printf "%s\n%s\n" "${install_section}" "\$(INSTALL_BIN) \$(1)${file_path}")
#		done
#	else
#		sed -i "s|@INSTALL_OPT_SECTION||" "${APP_MAKE_BUILD_PATH}/Makefile"
#	fi
#	install_section=$(printf "%s\n%s\n" "${install_section}" "endef" )
#}

#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Сохраняем данные из файлов ./${COMPILE_NAME}/postinst
# ./${COMPILE_NAME}/postrm в файл манифеста  /${COMPILE_NAME}/Makefile
#-------------------------------------------------------------------------------
create_makefile(){

#    extension=$(echo "${APPS_LANGUAGE}" | tr "[:upper:]" "[:lower:]")
    make_file="${COMPILE_PATH}/Makefile"
    PREV_PKGARCH=$(cat < "${make_file}" | sed -n 's/PKGARCH:=\(.*\)$/\1/p;' | sed 's/[ \t]//g')

    # копируем данные кода в папку для компиляции
    cp -rf "${APPS_ROOT}/${APP_NAME}/code/." "${APP_MAKE_BUILD_PATH}/files"

    section_list=$(cat < "${DEV_CONFIG_FILE}" | grep -v '^#' \
                    | grep "SECTION_" | sed 's|SECTION_\(.*\)=.*$|\1|g' \
                    | tr "[:upper:]" "[:lower:]")

    for section in ${section_list}; do
        create_package_section "${section}" "${make_file}"
    done

    sed -i "s|\(PKGARCH:=\).*|\1${ARCH_BUILD}|g;"  	"${make_file}"
    sed -i '/^[[:space:]]*$/d'  "${make_file}" 		"${make_file}"
    cp "${make_file}" "${APP_MAKE_BUILD_PATH}/Makefile"


}

#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Производим сборку пакета
#-------------------------------------------------------------------------------
do_package_make(){

set -x
    deb=${1}
    cd "${APPS_ROOT}/entware/"
#    rm -rf /apps/entware/tmp/info

    if ! grep -q "${APP_NAME}" "${BUILD_CONFIG}" ; then
    	make oldconfig <<< m
    	cat /apps/entware/package/utils/kotomka/files/compile/dump.txt
    	make tools/install ${deb}
    	make toolchain/install ${deb}
        cp -f "${BUILD_CONFIG}" "${COMPILE_PATH}/configs/${ARCH_BUILD}.config"
#        rm "${BUILD_CONFIG}.old"
    fi
    make package/"${APP_NAME}"/compile ${deb}
}


#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Производим первую сборку toolchain в контейнере
# В случае необходимости устанавливаем флаг отладки в YES
#-------------------------------------------------------------------------------



# Сохраняем данные из файлов ./${COMPILE_NAME}/postinst ./${COMPILE_NAME}/postrm в файл манифеста  /${COMPILE_NAME}/Makefile.<ext>
create_makefile
# Проверяем соответствие текущей архитектуры с предыдущей
# и в случае, если архитектуры разные - делаем очистку make dirclean
check_arch

show_line
echo "${PREF}Задействовано ${np} яд. процессора."
echo "${PREF}Режим отладки: $([ "${DEBUG}" = YES ] && echo "ВКЛЮЧЕН" || echo "ОТКЛЮЧЕН")"
echo "${PREF}Makefile для ${ARCH_BUILD} успешно импортирован."
echo "${PREF}Собираем пакет ${APP_NAME} вер. ${FULL_VERSION}"
show_line
echo "${PREF}Сборка запущена: $(zdump EST-3)"; show_line

time_start=$(date +%s)
# Собираем пакет

do_package_make "${deb}" || make dirclean

# копируем собранный пакет в папку где хранятся все сборки
ipk_path="${APPS_ROOT}/${APP_NAME}/ipk"
[ -d "${ipk_path}" ] || mkdir -p "${ipk_path}"
cp "$(get_ipk_package_file)" "${ipk_path}"

show_line
copy_and_install_package "ask";
show_line

time_end=$(date +%s)
echo "${PREF}Продолжительность сборки составила: $(time_diff "${time_start}" "${time_end}")"

