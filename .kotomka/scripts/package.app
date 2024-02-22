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

set -e

BASEDIR=$(dirname "$(dirname "${0}")")
. "${BASEDIR}/scripts/libraries/screen"
. "${BASEDIR}/scripts/libraries/status"

. "${BASEDIR}/scripts/libraries/library" "$(dirname "${BASEDIR}")"
. "${BASEDIR}/scripts/emate"

PREF=''
DEBUG=NO
PACKAGE_FINAL_PATH=package/${USER}/${APP_NAME}
APP_MAKE_BUILD_PATH=${APPS_ROOT}/entware/${PACKAGE_FINAL_PATH}
APPS_PATH=${APPS_ROOT}/${APP_NAME}
COMPILE_PATH=${APPS_PATH}/${ROOT_PATH}/${COMPILE_NAME}
ENTWARE_PATH=${APPS_ROOT}/entware
BUILD_CONFIG="${ENTWARE_PATH}/.config"

COMPILE_PATH=${COMPILE_PATH//\/\//\/}
mkdir_when_no "${APP_MAKE_BUILD_PATH}"
print_mess()(printf "${1}\n")

#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# обновляем ленту пакетов
#-------------------------------------------------------------------------------
feeds_update(){

	cur_path=$(pwd)
	cd "${ENTWARE_PATH}" || exit 1
	./scripts/feeds update "${APP_NAME}"
	./scripts/feeds install -a -f -p "${APP_NAME}"
	cd "${cur_path}" || exit 1
}

#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# обновляем ленту пакетов лишь однажды при первом запуске пакета
#-------------------------------------------------------------------------------
feeds_update_ones(){

	feeds_file=${ENTWARE_PATH}/feeds.conf

	cat < "${feeds_file}" | grep -q "${APP_NAME}" || {
		path_apps=$(dirname "${APP_MAKE_BUILD_PATH}")
		echo "src-link ${APP_NAME} ${path_apps}" >> "${feeds_file}"
		feeds_update
	}

}


#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# копируем данные кода в папку для компиляции
#-------------------------------------------------------------------------------
link_code_files(){

	app_make_build_path_files="${APP_MAKE_BUILD_PATH}/files"
	rm -rf "${APP_MAKE_BUILD_PATH}" && mkdir -p "${app_make_build_path_files}"

#	Делаем линки только на файлы разработки, в противном случае
#	(если сделать линк на папку) тут будут появляться файлы
#	задействованные в сборке зависимыми пакетами.
	if ! [ -d "${APP_MAKE_BUILD_PATH}/${SRC_PATH}" ] ; then
		src_dir="${APPS_PATH}/${ROOT_PATH}/${SRC_PATH}"
		mkdir -p "${APP_MAKE_BUILD_PATH}/${SRC_PATH}"

#		find "${src_dir}" -type d | while IFS= read -r -d '' _dir; do
		for _dir in $(find ${src_dir} -type d); do
			path_to_add=${_dir#${src_dir}}
			[ "${_dir}" = "${src_dir}" ] || mkdir -p "${APP_MAKE_BUILD_PATH}/${SRC_PATH}${path_to_add}/";
#			find "${_dir}" -maxdepth 1 -type f | while IFS= read -r -d '' _file ; do
			for _file in $(find ${_dir} -maxdepth 1 -type f );  do
				ln -s "${_file}" "${APP_MAKE_BUILD_PATH}/${SRC_PATH}${path_to_add}/"
			done
		done

	fi
#	Делаем линк на Makefile (файл манифеста)
	if ! [ -h "${app_make_build_path_files}/${OPT_PATH}" ] ; then
		ln -s "${APPS_PATH}/${ROOT_PATH}/${OPT_PATH}" "${app_make_build_path_files}"
	fi


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
    section_name_caps=$(echo "${section_name}" | awk '{print toupper($0)}')
    section_conf=$(get_config_value "SECTION_${section_name_caps}")

#	удаляем секцию из файла, чтобы обновить ее содержимое или просто удалить
#	sed -i "/define Package\/${APP_NAME}\/${section_name}/,/endef/d" "${make_file}"

    if [ -n "${section_conf}" ] && [ -f "${make_file}" ]; then
        if [ -f "${COMPILE_PATH}${DEV_MANIFEST_DIR_NAME}/${section_name}" ] ; then
#            section_text=$(cat < "${COMPILE_PATH}${DEV_MANIFEST_DIR_NAME}/${section_name}" | sed 's/^\(.*\)/\t\1/g')
#            if [ -n "${section_text}" ] ; then
#				section_text=$(printf "%s\n%s\n%s\n" "define Package/${APP_NAME}/${section_name}" "${section_text}" "endef")
##			 	last_cmd=$(cat < "${make_file}" | sed -n "s/\(^\$(eval.*${APP_NAME}\)/\1/p; s/\$/\\$/g; s/(/\\(/g; s/)/\\(/g")
##				awk -i inplace -v r="${section_text}\n${last_cmd}" "{gsub(/${last_cmd}/,r)}1" "${make_file}"
#			else
				sed -i "s/@${section_name_caps}//;" "${make_file}"
#			fi
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
                    | awk '{print tolower($0)}')

    for section in ${section_list}; do
        create_package_section "${section}" "${make_file}"
    done

    sed -i "s|\(PKGARCH:=\).*|\1${ARCH_BUILD}|g;"  	"${make_file}"
    sed -i '/^[[:space:]]*$/d'  					"${make_file}"
	sed -i 's/^endef/endef\n/g'						"${make_file}"

#	rm -f "${APP_MAKE_BUILD_PATH}/Makefile"
#	[ -f "${APP_MAKE_BUILD_PATH}/Makefile" ] || cp -f "${make_file}" "${APP_MAKE_BUILD_PATH}"
	[ -h "${APP_MAKE_BUILD_PATH}/Makefile" ] || ln -s "${make_file}" "${APP_MAKE_BUILD_PATH}"
}


#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Проверяем архитектуру сборки
#-------------------------------------------------------------------------------
check_arch(){

[ -z $APP_NAME ] && exit

	configs_path="${COMPILE_PATH}"
    mkdir_when_no "${configs_path}"

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
# Установка заплатки для решения проблемы
# с ошибкой 'file lt~obsolete.m4 not exist'
#-------------------------------------------------------------------------------
#aclocal_patch(){
#
#	m4_path=/apps/entware/package/master/samovar/src/libhttpserver-0.18.2/m4
#	aclocal_path=/apps/entware/staging_dir/host/share/aclocal
#	aclocal_files="libtool.m4,lt~obsolete.m4,ltoptions.m4,ltsugar.m4,ltversion.m4"
#
#	rm -f "${m4_path}/{${aclocal_files}}"
#	ln -s "${aclocal_path}/{${aclocal_files}}" "${m4_path}"
#}
#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Производим компиляцию пакета и обработку ошибок
#-------------------------------------------------------------------------------
do_compile_package(){


	make "${PACKAGE_FINAL_PATH}/compile" ${deb} ||  {

			[ "${DEBUG}" = YES ] || {
				[ -n "${GPT_TOKEN}" ] && {
					sep='---\n'
					LINE_WIDTH=120
					re_exp="^.*\.cpp.*error:|^.*\.h[p]{0,2}.*error:"
					make_text=$(make "${PACKAGE_FINAL_PATH}/compile" -j1 V=sc 2>&1)

					compile_text=$(echo "${make_text}" | grep -iE "${re_exp}" -B1 -A2 | tail -9)

					if [ -z "${compile_text}" ] ; then
						compile_text=$(echo "${make_text}" | grep -i "error:" -C10)
					else
						error_file_name=$(echo "${compile_text}" | grep -iE "${re_exp}"  | cut -d':' -f1 | sort -u)
					fi
					echo ''; print_line
					print_error ">> ОПИСАНИЕ ОШИБКИ:"
					print_line ; echo ''
					print_error "$(echo -e "${compile_text}" | sed 's/^\(.*\)/\t\1/' | fmt -w "${LINE_WIDTH}" )\n"
					print_line
					print_info ">> ПОДСКАЗКА ПО ОШИБКЕ:"
					print_line ; echo ''


					pref="Помоги мне понять, в чем может быть проблема. Компилятор C++11 нашел ошибки."
					post="Найди оптимальное решение по поиску и исправлению ошибок, указанных выше и
					напиши инструкцию шаг за шагом, по пунктам, как мне быстрее всего, исправить найденные ошибки.
					Отвечай только на русском языке."

					if [ -n "${error_file_name}" ]; then

						files_contain="${sep}"
						for src_file in ${error_file_name}; do
							file_full=$(find "${APP_MAKE_BUILD_PATH}/${SRC_PATH}" -type f -name "${src_file}")
							if [ "${files_contain}" = "${sep}" ]; then
								files_contain="${files_contain}#${src_file}\n\n$(cat "${file_full}" )"
							else
								files_contain="${files_contain}\n\n#${src_file}\n\n$(cat "${file_full}")"
							fi
						done
						files_contain="${files_contain}\n${sep}"

						files_contain="Код, в котором компилятор нашел ошибки:\n${files_contain}"
						compile_text="\nСписок ошибок:\n${sep}${compile_text}\n\n${sep}"
						question="${pref}\n${sep}${files_contain}${compile_text}${post}"
					else
						question="${pref}\n${compile_text}\n${post}"
					fi
					question=$(printf "${question}" | sed 's/"/\\\"/g;' | sed "s/\'/\\\"/g;" | sed 's/\\"/@/g;s/"$//g;s/@/\\"/g;s/[\t\r]//g;')
					answer=$(ask_chat "${question}" | sed 's/^\(.*\)/\t\1/' | fmt -w "${LINE_WIDTH}")
					print_info "${answer}\n"
					print_line
				}
			}
			exit 1
		}

}

#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Производим сборку пакета
#-------------------------------------------------------------------------------
do_package_make(){

    deb=${1}
    cd "${ENTWARE_PATH}" || exit 1

#	удаляем предыдущую версию пакета ipk перед сборкой текущей версии
    rm -f "$(get_ipk_package_file)"

    if ! grep -q "${APP_NAME}" "${BUILD_CONFIG}" ; then
#		Если имени нашего пакета нет в конфиг-файле меню ядра, то добавляем его
    	make oldconfig <<< m
    	make toolchain/install ${deb} || {
    		[ "${DEBUG}" = YES ] || make toolchain/install -j1 V=sc || make clean
    		exit 1
    	}
    fi

	make "${PACKAGE_FINAL_PATH}/clean" || {
		do_compile_package || {
			do_compile_package
		}
	} && do_compile_package

}

# cd /apps/entware && make menuconfig
# cd /apps/entware && ll /apps/entware/packages/utils/samovar/ &&  cat /apps/entware/packages/utils/kotomka/Makefile
# &&  make clean && make package/samovar/{clean,compile} -j1 V=sc


#

#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Печатаем заголовок компиляции
#-------------------------------------------------------------------------------
print_compile_header(){
#	ver_main=$(get_version_part "PACKAGE_VERSION");
#	ver_stage=$(get_version_part "PACKAGE_STAGE");
#	ver_release=$(get_version_part "PACKAGE_RELEASE");
#	full_ver=$(echo "${ver_main}${ver_stage}${ver_release}" | sed -e 's/[[:space:]]*$//' | tr ' ' '-')

	print_mess "${PREF}Задействовано ${BLUE}${np} яд. процессора.${NOCL}"
	if [ "${DEBUG}" = YES ]; then deb_status="${RED}ВКЛЮЧЕН${NOCL}"; else deb_status="${GREEN}ОТКЛЮЧЕН${NOCL}"; fi
	print_mess "${PREF}Режим отладки: ${deb_status}"
	print_mess "${PREF}Makefile успешно импортирован для ${BLUE}${ARCH_BUILD}${NOCL}."
#	print_mess "${PREF}Собираем пакет ${BLUE}${APP_NAME}${NOCL} вер. ${BLUE}${full_ver}${NOCL}"
	print_mess "${PREF}Собираем пакет ${BLUE}${APP_NAME}${NOCL} вер. ${BLUE}$(get_full_package_version)${NOCL}"
	check_arch								#	проверяем архитектуру сборки
	print_line
	print_mess "${PREF}Сборка запущена: ${BLUE}$(LC_ALL=ru_RU.UTF-8 date -d "+3 hours" | sed 's/Europe/Россия, Москва/' | tr -s " ")${NOCL}";
	print_line
}

#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Печатаем футроп компиляции
#-------------------------------------------------------------------------------
print_compile_foot(){
	start_time=${1}
	end_time=$(date "+%s")
	compile_period=$(time_diff "${start_time}" "${end_time}")
	print_mess "${PREF}${BLUE}Сборка пакета завершена.${NOCL}"
	print_mess "${PREF}${BLUE}Продолжительность составила:${compile_period}${NOCL}."
	print_line
}

#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Производим подготовительные действия: убираем все .DS_Store от мака
# Удаляем из памяти все дерево предыдущего процесса сборки
#-------------------------------------------------------------------------------
prepare_to_run(){
	find "${APPS_PATH}" -name .DS_Store -exec rm -f {} \;

	main_file_name=main #${APP_NAME}
	sed -i "s/int ${APP_NAME}()/int main()/" "${APP_MAKE_BUILD_PATH}/${DEV_SRC_PATH}/${main_file_name}.${DEVELOP_EXT}"
}

#-------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Производим первую сборку toolchain в контейнере
# В случае необходимости устанавливаем флаг отладки в YES
#-------------------------------------------------------------------------------
make_all(){
#set -x

	time_start=$(date "+%s")
	print_compile_header										# 	печатаем заголовок компиляции
	link_code_files												#	копируем данные кода в папку для компиляции
	prepare_to_run
	feeds_update_ones											#   обновляем фиды, если они еще не установлены
	create_makefile && {										#	создаем файл манифеста Makefile
		do_package_make "${deb}"								# 	производим сборку пакета
		copy_file "$(get_ipk_package_file)" "${PACKAGES_PATH}"	# 	копируем ipk файл в локальную папку paсkages
		print_line
		copy_and_install_package								# 	копируем и устанавливаем собранный пакет на устройство
		print_line
		print_compile_foot "${time_start}"						# 	печатаем футроп компиляции
	}
}

make_all || kill -9 "-$(pgrep -f make.run)"
