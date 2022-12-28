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
. "${BASEDIR}/scripts/library" "$(dirname "${BASEDIR}")"

DEBUG=NO
if echo "${DEBUG}" | grep -qE 'YES|yes'; then
    deb="-j1 V=sc"; np=1;
else
    deb="-j$(nproc)"; np="$(nproc)";
fi


APP_NAME=$(pwd | sed "s/.*\\${APPS_ROOT}\/\(.*\).*$/\1/;" | cut -d'/' -f1)
APP_MAKE_BUILD_PATH=${APPS_ROOT}/entware/package/utils/${APP_NAME}
APPS_PATH=${APPS_ROOT}/${APP_NAME}
COMPILE_PATH=${APPS_PATH}/${ROOT_PATH}/${COMPILE_NAME}
ENTWARE_PATH=${APPS_ROOT}/entware
BUILD_CONFIG="${ENTWARE_PATH}/.config"
PACKAGES_PATH="${APPS_PATH}/${ROOT_PATH}/${IPK_PATH}"

#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# копируем данные кода в папку для компиляции
#-------------------------------------------------------------------------------
copy_code_files(){
	# копируем данные кода в папку для компиляции
	build_files_path=${APP_MAKE_BUILD_PATH}/files
	rm -rf "${build_files_path}"
	mkdir_when_not "${build_files_path}/${OPT_PATH}"
    cp -rf "${APPS_PATH}/${ROOT_PATH}/${OPT_PATH}/." "${build_files_path}/${OPT_PATH}"
    mkdir_when_not "${build_files_path}/${SRC_PATH}"
    cp -rf "${APPS_PATH}/${ROOT_PATH}/${SRC_PATH}/." "${build_files_path}"
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
# Сохраняем данные из файлов ./${COMPILE_NAME}/postinst
# ./${COMPILE_NAME}/postrm в файл манифеста  /${COMPILE_NAME}/Makefile
#-------------------------------------------------------------------------------
create_makefile(){

    make_file="${COMPILE_PATH}/Makefile"

#    PREV_PKGARCH=$(cat < "${make_file}" | sed -n 's/PKGARCH:=\(.*\)$/\1/p;' | sed 's/[ \t]//g')
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
# Проверяем архитектуру сборки
#-------------------------------------------------------------------------------
check_arch(){

	configs_path="${COMPILE_PATH}"
    mkdir_when_not "${configs_path}"

    if [ -f "${BUILD_CONFIG}" ]; then
#    	архитектура совпадает от предыдущей сборки?
    	if ! cat < "${BUILD_CONFIG}" | grep -E "CONFIG_TARGET_BOARD.*${ARCH_BUILD}" | grep -qv '#'; then
    		cp "$(ls "${APPS_ROOT}"/entware/configs/"${ARCH_BUILD}".config)" "${BUILD_CONFIG}"
    	else
    		echo 'SUPPER!!!'
    	fi
    else
    	cp "$(ls "${APPS_ROOT}"/entware/configs/"${ARCH_BUILD}".config)" "${BUILD_CONFIG}"
    fi

}


#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Производим сборку пакета
#-------------------------------------------------------------------------------
do_package_make(){

    deb=${1}
    cd "${ENTWARE_PATH}"
echo 1
    if ! grep -q "${APP_NAME}" "${BUILD_CONFIG}" ; then
echo 2
    	make oldconfig <<< m
    	make tools/install ${deb} || make clean; make tools/install -j1 V=sc
    	make toolchain/install ${deb} || make toolchain/install -j1 V=sc
    fi
echo 3
    make package/"${APP_NAME}"/compile ${deb} || make package/"${APP_NAME}"/compile -j1 V=sc
echo 4
}
# cd /apps/entware && make menuconfig
# cd /apps/entware && ll /apps/entware/packages/utils/kotomka/ &&  cat /apps/entware/packages/utils/kotomka/Makefile
# &&  make package/kotomka/compile -j1 V=sc

#

#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Производим первую сборку toolchain в контейнере
# В случае необходимости устанавливаем флаг отладки в YES
#-------------------------------------------------------------------------------
main_run(){

	# копируем данные кода в папку для компиляции
	copy_code_files

#	формируем файл манифеста для сборки пакета
	create_makefile

	# Проверяем соответствие текущей архитектуры с предыдущей
	# и в случае, если архитектуры разные - делаем очистку make dirclean
	check_arch

	echo -e "${PREF}${BLUE}Задействовано ${np} яд. процессора.${NOCL}"
	echo -e "${PREF}${BLUE}Режим отладки: $([ "${DEBUG}" = YES ] && echo "ВКЛЮЧЕН" || echo "ОТКЛЮЧЕН")${NOCL}"
	echo -e "${PREF}Makefile для ${GREEN}${ARCH_BUILD}${NOCL} успешно импортирован."
	echo -e "${PREF}${BLUE}Собираем пакет ${APP_NAME} вер. ${FULL_VERSION}${NOCL}"
	show_line
	echo -e "${PREF}${BLUE}Сборка запущена: $(zdump EST-3)${NOCL}"; show_line

	time_start=$(date +%s)
	# Собираем пакет

	do_package_make "${deb}"

	# копируем собранный пакет в папку где хранятся все сборки
	mkdir_when_not "${PACKAGES_PATH}" && cp "$(get_ipk_package_file)" "${PACKAGES_PATH}"

	show_line
	copy_and_install_package "ask";
	show_line

	time_end=$(date +%s)
	echo -e "${PREF}${BLUE}Продолжительность сборки составила: $(time_diff "${time_start}" "${time_end}")${NOCL}"
}
main_run

exit 0