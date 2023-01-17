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



BASEDIR=$(dirname "$(dirname "${0}")")
. "${BASEDIR}/scripts/library" "$(dirname "${BASEDIR}")"

PREF='>> '
DEBUG=NO
APP_NAME=$(pwd | sed "s/.*\\${APPS_ROOT}\/\(.*\).*$/\1/;" | cut -d'/' -f1)
APP_MAKE_BUILD_PATH=${APPS_ROOT}/entware/package/utils/${APP_NAME}
APPS_PATH=${APPS_ROOT}/${APP_NAME}
COMPILE_PATH=${APPS_PATH}/${ROOT_PATH}/${COMPILE_NAME}
ENTWARE_PATH=${APPS_ROOT}/entware
BUILD_CONFIG="${ENTWARE_PATH}/.config"
PACKAGES_PATH="${APPS_ROOT}/${APP_NAME}/${ROOT_PATH}/${IPK_PATH}"

print_mess()(echo -e "${1}")
#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# копируем данные кода в папку для компиляции
#-------------------------------------------------------------------------------
copy_code_files(){

	# копируем данные кода в папку для компиляции
	build_files_path=${APP_MAKE_BUILD_PATH}/files
	rm -rf "${build_files_path}"
    copy_dir "${APPS_PATH}/${ROOT_PATH}/${OPT_PATH}" "${build_files_path}"
    copy_dir "${APPS_PATH}/${ROOT_PATH}/${SRC_PATH}" "${build_files_path}"
}

#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# устанавливаем параметр deb для компилирования
#-------------------------------------------------------------------------------
if echo "${DEBUG}" | grep -qE 'YES|yes'; then
	deb="-j1 V=sc"; np=1;
else
	deb="-j$(nproc)"; np="$(nproc)";
fi

#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Создаем секцию в Packages/* в файле манифеста /${COMPILE_NAME}/Makefile
#-------------------------------------------------------------------------------
create_package_section(){

    section_name=${1}
    make_file="${2}"
    section_name_caps=$(echo "${section_name}" | tr '[:lower:]' '[:upper:]')
    section_conf=$(get_config_value "SECTION_${section_name_caps}")

    if [ -n "${section_conf}" ]; then
        if [ -f "${COMPILE_PATH}${DEV_MANIFEST_DIR_NAME}/${section_name}" ] ; then
            section_text=$(cat < "${COMPILE_PATH}${DEV_MANIFEST_DIR_NAME}/${section_name}")
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
# создаем файл манифеста Makefile - собираем его различные секции
#-------------------------------------------------------------------------------
create_makefile(){

    make_file="${COMPILE_PATH}/Makefile"
    section_list=$(cat < "${DEV_CONFIG_FILE}" | grep -v '^#' \
                    | grep "SECTION_" | sed 's|SECTION_\(.*\)=.*$|\1|g' \
                    | tr '[:upper:]' '[:lower:]')

    for section in ${section_list}; do
        create_package_section "${section}" "${make_file}"
    done

    sed -i "s|\(PKGARCH:=\).*|\1${ARCH_BUILD}|g;"  	"${make_file}"
    sed -i '/^[[:space:]]*$/d'  					"${make_file}"

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
    		cp "$(ls "${APPS_ROOT}/entware/configs/${ARCH_BUILD}.config")" "${BUILD_CONFIG}"
    		print_mess "${PREF}${BLUE}Архитектура новая${NOCL}, файл конфигурации переписан!"
    	else
    		print_mess "${PREF}${BLUE}Архитектура прежняя${NOCL}, что и была в предыдущей сборке пакета."
    	fi
    else
    	cp "$(ls "${APPS_ROOT}/entware/configs/${ARCH_BUILD}.config")" "${BUILD_CONFIG}"
    	print_mess "${PREF}${BLUE}Архитектура новая${NOCL}, файл конфигурации отсутствует и он переписан!"
    fi

}


#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Производим сборку пакета
#-------------------------------------------------------------------------------
do_package_make(){

    deb=${1}
    cd "${ENTWARE_PATH}" || exit 1

	rm -f /apps/entware/tmp/info/.files-* /apps/entware/tmp/info/.overrides-*
	find /apps/entware/ -type f -name '.files-packageinfokageinfo*' -exec rm {} \;
#	удаляем предыдущую версию пакета ipk перед сборкой текущей версии
    rm -f "$(get_ipk_package_file)"

    if ! grep -q "${APP_NAME}" "${BUILD_CONFIG}" ; then
#		Если имени нашего пакета нет в конфиг-файле меню ядра, то добавляем его
    	make oldconfig <<< m

    	make tools/install ${deb} || {
    		make tools/install -j1 V=sc || make clean
    		exit 1
    	}
    	make toolchain/install ${deb} || {
    		make toolchain/install -j1 V=sc || make clean
    		exit 1
    	}
    fi

	make "package/${APP_NAME}/compile" ${deb} || {
		make "package/${APP_NAME}/compile" -j1 V=sc || make "package/${APP_NAME}/clean"
		exit 1
	}

}

# cd /apps/entware && make menuconfig
# cd /apps/entware && ll /apps/entware/packages/utils/kotomka/ &&  cat /apps/entware/packages/utils/kotomka/Makefile
# &&  make package/kotomka/compile -j1 V=sc

#

#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Печатаем заголовок компиляции
#-------------------------------------------------------------------------------
print_compile_header(){
	print_mess "${PREF}Задействовано ${BLUE}${np} яд. процессора.${NOCL}"
	if [ "${DEBUG}" = YES ]; then deb_status="${RED}ВКЛЮЧЕН${NOCL}"; else deb_status="${GREEN}ОТКЛЮЧЕН${NOCL}"; fi
	print_mess "${PREF}Режим отладки: ${deb_status}"
	print_mess "${PREF}Makefile успешно импортирован для ${BLUE}${ARCH_BUILD}${NOCL}."
	print_mess "${PREF}Собираем пакет ${BLUE}${APP_NAME}${NOCL} вер. ${BLUE}${FULL_VERSION}${NOCL}"
	check_arch								#	проверяем архитектуру сборки
	show_line
	echo -e "${PREF}Сборка запущена: ${BLUE}$(date -d "+3 hours")${NOCL}";
	show_line
}

#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Печатаем футроп компиляции
#-------------------------------------------------------------------------------
print_compile_foot(){
	start_time=${1}
	end_time=$(date "+%s")
	compile_period=$(time_diff "${start_time}" "${end_time}")
	echo -e "${PREF}${BLUE}Сборка пакета завершена.${NOCL}"
	echo -e "${PREF}${BLUE}Продолжительность составила:${compile_period}${NOCL}."
	show_line
}


#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Производим первую сборку toolchain в контейнере
# В случае необходимости устанавливаем флаг отладки в YES
#-------------------------------------------------------------------------------
make_all(){

	time_start=$(date "+%s")
	print_compile_header										# 	печатаем заголовок компиляции
	copy_code_files												#	копируем данные кода в папку для компиляции
	create_makefile												#	создаем файл манифеста Makefile
 	do_package_make "${deb}"									# 	производим сборку пакета
	copy_file "$(get_ipk_package_file)" "${PACKAGES_PATH}"		# 	копируем ipk файл в локальную папку paсkages
	show_line
	copy_and_install_package									# 	копируем и устанавливаем собранный пакет на устройство
	show_line
	print_compile_foot "${time_start}"							# 	печатаем футроп компиляции
}

make_all

