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

RED="\033[1;31m";
BLUE="\033[36m";
NOCL="\033[m";
PREF=''
SEP=

PACKAGE_APP_NAME=kotomka
DEV_NAME_PATH=.${PACKAGE_APP_NAME}
PATH_PREFIX="../."
DEV_CONFIG_NAME=build.conf
DEV_CONFIG_FILE="../../build.conf"
DEVELOP_EXT=''

. "${DEV_CONFIG_FILE}"

. ./libraries/screen
set_esc_colors
set_esc_sims
set_esc_eraser
set_esc_cursor

. ./libraries/status
. ./libraries/traps

. ./libraries/library "${PATH_PREFIX}."

#-------------------------------------------------------------------------------
# Возвращаем 0 в случае, если текущая система является MAC OS
#-------------------------------------------------------------------------------
is_mac_os_x()(uname -a | grep -q Darwin)


#-------------------------------------------------------------------------------
# Запускаем разные версии awk в зависимости от ОС
#-------------------------------------------------------------------------------
awkfun()(if is_mac_os_x ; then gawk "$@"; else awk "$@"; fi)


#-------------------------------------------------------------------------------
# Запускаем разные версии sed в зависимости от ОС
#-------------------------------------------------------------------------------
sedi()(if is_mac_os_x ; then sed -i '' "$@"; else sed -i "$@"; fi)


#-------------------------------------------------------------------------------
# Получаем необходимую информацию о версии пакета
#-------------------------------------------------------------------------------
get_version(){
	part=${1}
	cat < "${DEV_CONFIG_FILE}" | grep "${part}" | cut -d'=' -f2
}
#-------------------------------------------------------------------------------
# Устанавливаем информацию о версии пакета
#-------------------------------------------------------------------------------
set_version_part(){
	part=${1}
	value=${2}
	sedi "s|\(${part}=\).*|\1${value}|" "${DEV_CONFIG_FILE}"
}


#-------------------------------------------------------------------------------
PACKAGE_VERSION=$(get_version PACKAGE_VERSION)
PACKAGE_STAGE=$(get_version PACKAGE_STAGE)
PACKAGE_RELEASE=$(get_version PACKAGE_RELEASE)
#-------------------------------------------------------------------------------
FULL_VERSION="${PACKAGE_VERSION} ${PACKAGE_RELEASE}";
[ -n "${PACKAGE_STAGE}" ] && FULL_VERSION="${PACKAGE_VERSION} ${PACKAGE_STAGE} ${PACKAGE_RELEASE}";
#-------------------------------------------------------------------------------

DEBUG=YES # флаг отладки процесса сборки образа
#-------------------------------------------------------------------------------
APP_NAME=$(pwd | sed "s/.*\\${APPS_ROOT}\/\(.*\).*$/\1/;" | cut -d'/' -f1)
PACKAGE_NAME=${APP_NAME}
IMAGE_NAME=$(echo "${DOCKER_ACCOUNT_NAME}" | awk '{print tolower($0)}')/${APP_NAME}_dev

#-------------------------------------------------------------------------------
#	Пути к файлам на машине разработчика
#-------------------------------------------------------------------------------
DOCKER_FILES_PATH=../docker
DOCKER_FILE=${DOCKER_FILES_PATH}/Dockerfile

#-------------------------------------------------------------------------------
#	Пути к файлам внутри контейнера
#-------------------------------------------------------------------------------
SCRIPTS_PATH=${APPS_ROOT}/${APP_NAME}/${DEV_NAME_PATH}/scripts
#SCRIPT_TO_MAKE=${SCRIPTS_PATH}/package.app
SCRIPT_TO_MAKE=${SCRIPTS_PATH}/make.run
SCRIPT_TO_COPY=${SCRIPTS_PATH}/copy.app
SCRIPT_TO_CLEAN=${SCRIPTS_PATH}/clean.app
SCRIPT_TO_TEST=${SCRIPTS_PATH}/testsrun.app
WORK_PATH_IN_CONTAINER="${APPS_ROOT}/${APP_NAME}/${DEV_NAME_PATH}"

#-------------------------------------------------------------------------------
#  Формируем имя контейнера в зависимости от архитектуры процессора.
#-------------------------------------------------------------------------------
get_container_name()(echo "${APP_NAME}-${1}" | awk '{print tolower($0)}')


#-------------------------------------------------------------------------------
#  Получаем id контейнера по его имени.
#-------------------------------------------------------------------------------
get_image_id()(docker image ls -q "${IMAGE_NAME}")

#-------------------------------------------------------------------------------
#  Сбрасываем в первоначальное состояние пакет до установки языка разработки.
#-------------------------------------------------------------------------------
reset_data(){

	answer=''; read_ynq "Будут удалены все контейнеры и исходники приложения, ${RED}УВЕРЕНЫ${NOCL} [Y/N/Q]? " answer
    [ "${answer}" = y ] && {
    	print_line
    	ready "${PREF}Данные удалены "
		purge_containers "$(docker ps -aq -f name="${APP_NAME}")" &>/dev/null && {
			rm -rf "${PATH_PREFIX}${DEV_ROOT_PATH}"
    		docker system prune --all --force --volumes &>/dev/null

			print_warning "${PREF}Пакет сброшен в первоначальное состояние."
			print_warning "${PREF}Папка с исходниками ${RED}${DEV_ROOT_PATH}${NOCL} удалена!"
			print_warning "${PREF}Удалены все контейнеры приложения ${RED}${APP_NAME}${NOCL}!"
		} && when_ok "УСПЕШНО" || when_err "с ошибками!"

		print_line
    }


}


#-------------------------------------------------------------------------------
#  Получаем список архитектур для которых ведется разработка.
#  в соответствии с правилами указанными в DEV_CONFIG_FILE
#-------------------------------------------------------------------------------
get_arch_list(){

    cat < "${DEV_CONFIG_FILE}" \
        | grep -v '#' | sed -n "s|ARCH_LIST=\"\(.*\)\"$|\1|p" | tr ' ' '\n'
}


#-------------------------------------------------------------------------------
#  Создаем файл манифеста для заданного типа языка разработки
#-------------------------------------------------------------------------------
prepare_makefile(){

    app_router_dir=$(escape "/opt${APPS_ROOT}/${APP_NAME}")
    github_url=$(escape "https://github.com/${GITHUB_ACCOUNT_NAME}/${APP_NAME}")
    code_dir=$(escape "${APPS_ROOT}/${APP_NAME}${DEV_ROOT_PATH//./}/")
    source_dir=$(escape "${APPS_ROOT}/${APP_NAME}${DEV_ROOT_PATH//./}/${DEV_SRC_PATH}")

    make_file="${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_COMPILE_NAME}Makefile"

    sedi "s/@APP_NAME/$(escape "${PACKAGE_NAME}")/g; \
         s/@PACKAGE_VERSION/$(escape "${PACKAGE_VERSION}" | tr -d ' ')/g; \
         s/@PACKAGE_STAGE/$(escape "${PACKAGE_STAGE}" | tr -d ' ')/g; \
         s/@APP_ROUTER_DIR/${app_router_dir}/g; \
         s/@PACKAGE_RELEASE/$(escape "${PACKAGE_RELEASE}")/g; \
         s/@LICENCE/$(escape "${LICENCE}")/g; \
         s/@AUTHOR/$(escape "${AUTHOR_NAME}")/g; \
         s/@EMAIL/$(escape "${AUTHOR_EMAIL}")/g; \
         s/@GITHUB/${github_url}/g; \
         s/@PKGARCH/${github_url}/g; \
         s/@CATEGORY/$(escape "${PACKAGE_CATEGORY}")/g; \
         s/@SUBMENU/$(escape "${PACKAGE_SUBMENU}")/g; \
         s/@TITLE/$(escape "${PACKAGE_TITLE}")/g; \
         s/@SOURCE_DIR/${source_dir}/g; \
         s/@CODE_DIR/${code_dir}/g;" ${make_file}

    awkfun -v r="${PACKAGE_DESCRIPTION}" '{gsub(/@DESCRIPTION/,r)}1' ${make_file} > temp.txt && mv temp.txt ${make_file}

}


#-------------------------------------------------------------------------------
#  Создаем папку и файл, если они не существуют и если переменная
#  установлена в значение YES
#-------------------------------------------------------------------------------
create_sections (){

    full_path=${1}
    section_list=$(cat < "${DEV_CONFIG_FILE}" | grep "SECTION_" | grep -v "^#")

    for section in ${section_list} ; do
        name_caps=$(echo "${section}" | sed "s|^SECTION_\(.*\)=.*$|\1|")
        name=$(echo "${name_caps}" | awk '{print tolower($0)}')

        if echo "${section}" | sed "s|^PACKAGE_.*=\(.*\)$|\1|" | grep -q "YES" ; then
            [ -d "${full_path}" ] || mkdir -p "${full_path}"
            touch "${full_path}/${name}"
        else
            sedi "s|@${name_caps}||" "${makefile_path}Makefile"
        fi
    done

}

#-------------------------------------------------------------------------------
#  Производим первоначальные настройки пакета в зависимости от заявленного языка разработки
#-------------------------------------------------------------------------------
set_dev_language(){

	# Исправляем ошибки при различном написании языка разработки (русский и англиский)
	case "${DEV_LANGUAGE,,}" in
		си|c|cc|сс|ccc|ссс)
			DEVELOP_EXT='c'				# на английском
			lang="Си"					# на русском
			;;
		с++|cpp|c++|срр)
			DEVELOP_EXT='cpp'			# на английском
			lang="С++"					# на английском
			;;
		bash|sh|shell)
			DEVELOP_EXT='sh'			# на английском
			lang="Bash"
			;;
	esac

    print_warning "${PREF}Заявленным языком разработки является '${lang}'"
    print_warning "${PREF}Производим замену файлов в соответствии с установками в ${DEV_CONFIG_NAME}"
    print_line

    mainfile_path="${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_SRC_PATH}"
    makefile="${mainfile_path}/Makefile"
    mainfiles="${mainfile_path}/main.*"
    rm -f "${makefile}" "${mainfiles}"

    case ${DEVELOP_EXT} in
        cpp|c)
            cp -f "../templates/code/make/Makefile.${DEVELOP_EXT}"      "${makefile}"
            sedi  "s|@APP_NAME|${APP_NAME}|g"                           "${makefile}"
            ext_file=$(echo "${mainfiles}" | sed "s|main\.\*$|main.${DEVELOP_EXT}|")
            cp -f "../templates/code/src/main.${DEVELOP_EXT}"           "${ext_file}"
            ;;

        bash)
            cp "../templates/code/src/main.${DEVELOP_EXT}"             "${mainfile_path}/${APP_NAME}"
            ;;
        *)
            print_line
            print_error "${PREF}Не распознан язык разработки в файле ${DEV_CONFIG_FILE}"
            print_warning "${PREF}Текущее значение DEV_LANGUAGE = ${DEV_LANGUAGE}."
            print_warning "${PREF}Задайте одно из значений: C (Си), CPP (C++) или BASH."
            print_warning "${PREF}Значения можно задавать на русском или английском."
            print_line
            exit 1
            ;;
    esac

    manifest_scripts_path="${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_COMPILE_NAME}${DEV_MANIFEST_DIR_NAME}"
#   создаем скрипты для сборки файла манифеста
    mkdir_when_no "${manifest_scripts_path}"

#   и копируем сам файл манифеста
#    makefile_path="${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_COMPILE_NAME}/${arch}"
    makefile_path="${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_COMPILE_NAME}"
    mkdir_when_no "${makefile_path}"
    cp -f "../templates/compile/Manifest.${DEVELOP_EXT}"     "${makefile_path}/Makefile"

    #   создаем секции манифеста и файлы для них
    create_sections "${manifest_scripts_path}"
    sedi '/^[[:space:]]*$/d' "${makefile_path}Makefile"

	prepare_makefile

#   меняем имя пакета в файле для удаленных тестов
	mkdir_when_no "${DEV_REMOTE_TESTS_NAME}"
    cp -rf ../templates/tests/* ${DEV_REMOTE_TESTS_NAME}
    sedi "s|@APP_NAME|${APP_NAME}|g"  ${DEV_REMOTE_TESTS_NAME}/modules/hello.bats

}


#-------------------------------------------------------------------------------
#  Проверяем соответствия флага языка разработки и текущий манифест для сборки пакета
#-------------------------------------------------------------------------------
check_dev_language(){

    manifest_file=$(find ../.. -type f | grep "${DEV_ROOT_PATH}/Makefile" | head -1)

    if [ -n "${manifest_file}" ]; then
        if ! cat < "${manifest_file}" | grep -qi "для ${DEVELOP_EXT}"; then
            print_error "${PREF}Обнаружено несоответствие файлов проекта с заявленным"
            print_error "${PREF}языком разработки для архитектуры процессора '${arch}'"
            set_dev_language
        fi
    else
        set_dev_language
    fi
}

#-------------------------------------------------------------------------------
#  Создаем структуру папок для разработки в случае
#  инициализации проекта (описана в build.conf) передаем
#  внутрь, как минимум одно и как максимум несколько названий
#  архитектуры процессоров разделенных пробелами
#-------------------------------------------------------------------------------
prepare_code_structure(){

    mkdir_when_no  "${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_SRC_PATH}"

#   создаем папку с тестами
    [ -n "${DEV_REMOTE_TESTS_NAME}" ] && ! [ -d "${DEV_REMOTE_TESTS_NAME}" ] && {
        mkdir_when_no "${DEV_REMOTE_TESTS_NAME}"
        cp -rf ../templates/tests/* ${DEV_REMOTE_TESTS_NAME}
        sedi "s|@APP_NAME|${APP_NAME}|g"  "${DEV_REMOTE_TESTS_NAME}/modules/hello.bats"
    }

#   создаем папку /opt с минимальной структурой, как на устройстве
    opt_path="${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_OPT_PATH}"
    [ -n "${DEV_OPT_PATH}" ] && ! [ -d "${opt_path}" ] && {
        mkdir -p "${opt_path}/etc" "${opt_path}/bin" "${opt_path}/etc/init.d"
        mkdir -p "${opt_path}/etc/ndm/netfilter.d" "${opt_path}/etc/ndm/ifstatechanged.d"
        mkdir -p "${opt_path}/etc/ndm/fs.d" "${opt_path}/etc/ndm/wan.d"
    }
#   создаем папку /packages
    if [ -n "${DEV_IPK_NAME}" ] && ! [ -d "${DEV_IPK_NAME}" ]; then
        mkdir -p "${DEV_IPK_NAME}"
    fi

    if ! [ -d "${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_COMPILE_NAME}" ]; then
        mkdir -p "${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_COMPILE_NAME}${DEV_MANIFEST_DIR_NAME}"
        check_dev_language
    fi

}
#-------------------------------------------------------------------------------
#  Готовим систему к запуску пакета
#-------------------------------------------------------------------------------
check_system(){

#    Если система MAC OS X
    if is_mac_os_x; then
        if ! [ -f /usr/local/bin/gawk ] ; then
            print_warning "${PREF}Производим установку недостающего пакета 'gawk' для 'Mac OS X'"
            print_line
            brew install gawk
        fi
        SEP=''
    fi

}


#-------------------------------------------------------------------------------
#  Получаем ID контейнера по его имени
#-------------------------------------------------------------------------------
get_container_id(){
    container_name=${1}
	container_id=$(docker ps | grep "${container_name}" | head -1 | cut -d' ' -f1 )
	[ -z "${container_id}" ] && container_id=$(docker ps -a | grep "${container_name}" | head -1 | cut -d' ' -f1 )
	echo "${container_id}"
}


#-------------------------------------------------------------------------------
#  Получаем список контейнеров, которые были созданы
#  $1 - тип отображаемых контейнеров
#	    0 или отсутствие параметра - отображаем все имеющиеся контейнеры
#		    запущенные контейнеры помечаются звездочкой зеленого цвета
#		1 - запущенные контейнеры
#		2 - остановленные контейнеры
#-------------------------------------------------------------------------------
get_container_list(){
	running=$(docker ps -aq --filter name="${APP_NAME}-*" --filter status=running --format "{{.Names}}" | \
	 	   			 sed -n "s/^\(.*\)/\*\1/p")
	exited=$(docker ps -aq --filter name="${APP_NAME}-*" --filter status=exited --format "{{.Names}}" )
	[ -n "${running}" ] && det=' ' || det=''
	printf "${running}${det}${exited}"
}

#-------------------------------------------------------------------------------
#  Останавливаем и удаляем контейнер
#-------------------------------------------------------------------------------
purge_containers(){
	container_id="${1}"
	docker stop ${container_id}
	docker rm ${container_id}
}

get_container_log(){
	container_id_or_name=$(echo "${1}" | awk '{print toupper($0)}')
	docker logs "${1}" --details --tail 150 | grep -iE 'error|fault' -A100 -B10
}

print_error_log_line(){

	mess=${1}; sim=${2:--}
	sim_len=$(((LENGTH-${#mess})/2))

	printf "${RED}%b%${sim_len}s${NOCL}" " " | tr ' ' "${sim}"
	echo -ne " ${GREEN}${mess}${NOCL} "
	printf "${RED}%b%${sim_len}s${NOCL}\n" " " | tr ' ' "${sim}"

}
#-------------------------------------------------------------------------------
#  Запускаем в случае, если при запуске контейнера произошла ошибка
#-------------------------------------------------------------------------------
run_when_error(){

	container_id_or_name=$(echo "${1}" | awk '{print toupper($0)}')
#	error_tag="${RED}ОШИБКА${NOCL}"
	errors_list='error|fault'
	echo ''

	err_log=$(docker logs "${1}" --details --tail 150 | grep -iE "${errors_list}" -A100 -B10)
	if [ -n "${err_log}" ]; then

		print_line ;
		center "${RED}В ПРОЦЕССЕ РАБОТЫ ВОЗНИКЛИ ОШИБКИ${NOCL}"
		print_line

		print_error_log_line "НАЧАЛО ЖУРНАЛА КОНТЕЙНЕРА ${container_id_or_name}" '⬇'
		print_line -

		printf "${YELLOW}"
		printf "${err_log}\n" | sed 's/^\(.*\)/\t\t\1/g'
		printf "${NOCL}\n"


		print_line -
		print_error_log_line "КОНЕЦ ЖУРНАЛА КОНТЕЙНЕРА ${container_id_or_name}" '⬆'
		print_line
		echo

	fi


}

#-------------------------------------------------------------------------------
#  Запускаем Docker exec с параметрами
#   $1 - container_id
#   $2 - скрипт для запуска внутри контейнера сразу после входа в него
#   $3 - root, если пусто, то входим под именем текущего пользователя
#   $4 - архитектура процессора
#-------------------------------------------------------------------------------
docker_exec(){

    container_id=${1};
    script_to_run=${2};
    root=${3};
    arch_build=$(echo "${4}" | awk '{print tolower($0)}')

    if [ "${root}" = root ]; then user="root:root"; else user="${USER}:${GROUP}"; fi
    if [ -z "${script_to_run}" ]; then WORK_PATH_IN_CONTAINER="${APPS_ROOT}/entware"; TERMINAL='true';
    else TERMINAL='false'; fi

	# Создаем их, если не существуют
	set_user_group_for_path "${APPS_ROOT}/${APP_NAME}" "${USER}" "${U_ID}" "${GROUP}" "${G_ID}"

#	Устанавливаем права на папку сборки, пользователя, который должен быть по умолчанию
	mkdir -p ${PATH_TO_MY_APP}/code && chown -R ${user_name}:${group_name} ${PATH_TO_MY_APP}/code &>/dev/null

    docker exec \
			-i -t \
			--workdir "${WORK_PATH_IN_CONTAINER}" \
			--env ROUTER_LIST="${ROUTER_LIST}" \
			--env COMPILE_NAME="${DEV_COMPILE_NAME}" \
			--env ROOT_PATH="${DEV_ROOT_PATH//.\//}" \
			--env OPT_PATH="${DEV_OPT_PATH}" \
           	--env SRC_PATH="${DEV_SRC_PATH}" \
           	--env GPT_TOKEN="${GPT_TOKEN}" \
           	--env ARCH_BUILD="${arch_build}" \
			--env APP_NAME="${APP_NAME}" \
           	--env IPK_PATH="${DEV_IPK_NAME}" \
           	--env TERMINAL="${TERMINAL}" \
           	--user "${user}" \
           	 "${container_id}" /bin/bash ${script_to_run}  || {

           	 	when_err "ОШИБКА" "$(get_container_log "${container_name}")"
           	 	print_warning "Сейчас контейнер будет остановлен, удален и пересобран."
				container_name="$(get_container_name "${arch_build}")"
				container_id=$(docker ps -qa  --filter name="${container_name}")

				docker stop "${container_id}" &>/dev/null && docker rm "${container_id}" &>/dev/null
				container_manager_to_make "${SCRIPT_TO_MAKE}" "" "${arg_1}"
				exit 0;

           	 }





#		if [ -n "${script_to_run}" ] ; then
#			run_when_error "${container_name}"
#			exit 1
#		else
#		docker stop "${container_id}"
#		docker rm "${container_id}"
#		docker_run "" "${container_name}" "${arch_build}" "${root}"
#		container_name="$(get_container_name "${arch_build}")"
#		container_id=$(docker ps -qa  --filter name="${container_name}")
#		docker_exec "${container_id}" "${SCRIPT_TO_CLEAN}" "${root}" "${arch_build}"
#		fi


}

#
#-------------------------------------------------------------------------------
#  Запускаем Docker run с параметрами
#   $1 - скрипт для запуска внутри контейнера сразу после входа в него
#   $2 - имя контейнера
#   $3 - архитектура процессора
#-------------------------------------------------------------------------------
docker_run(){

    script_to_run=${1};
    container_name=${2};
    arch_build=$(echo "${3}" | awk '{print tolower($0)}')
    user=${4}
    context=$(dirname "$(dirname "$(pwd)")")

	# Создаем их, если не существуют
	set_user_group_for_path "${APPS_ROOT}/${APP_NAME}" "${USER}" "${U_ID}" "${GROUP}" "${G_ID}"

    if [ -n "${container_name}" ] ; then name_container="--name ${container_name}"; else name_container=""; fi
	if [ -z "${script_to_run}" ]; then WORK_PATH_IN_CONTAINER="${APPS_ROOT}/entware"; TERMINAL='true';
    else TERMINAL='false'; fi

    docker run \
           	--workdir "${WORK_PATH_IN_CONTAINER}" \
           	-i -t -d \
			--env ROUTER_LIST="${ROUTER_LIST}" \
           	--env ARCH_BUILD="${arch_build}" \
           	--env COMPILE_NAME="${DEV_COMPILE_NAME}" \
			--env ROOT_PATH="${DEV_ROOT_PATH//.\//}" \
			--env OPT_PATH="${DEV_OPT_PATH}" \
           	--env SRC_PATH="${DEV_SRC_PATH}" \
			--env GPT_TOKEN="${GPT_TOKEN}" \
		   	--env IPK_PATH="${DEV_IPK_NAME}" \
			--env APP_NAME="${APP_NAME}" \
			--env TERMINAL="${TERMINAL}" \
		   	--env TZ=Europe/Moscow \
           	--user "${user}" \
           	${name_container} \
           	--mount type=bind,src="${context}",dst="${APPS_ROOT}"/"${APP_NAME}" \
           	"$(get_image_id)" /bin/bash &>/dev/null || when_err "ОШИБКА" "$(get_container_log "${container_name}")"





#		if [ -n "${script_to_run}" ] ; then
#			run_when_error "${container_name}"
#			exit 1
#		else
#
#			docker_run "${SCRIPT_TO_CLEAN}" "${container_name}"  "${arch_build}" "${user}"
#		fi
#	else
#		docker stop ${container_name} &>/dev/null
#    fi
}


#-------------------------------------------------------------------------------
# Подключаемся к контейнеру когда он уже запущен
#-------------------------------------------------------------------------------
connect_when_run(){

   	script_to_run=${1}
   	run_with_root=${2}
   	container_id_running=${3}
   	arch=${4}
   	container_name=${5}
   	_user=${USER}
    [ "${run_with_root}" = yes ] && _user=root

   	ready "${PREF}Контейнер разработки ${BLUE}${container_name}${NOCL}" && when_ok "ЗАПУЩЕН"
    ready "${PREF}Производим подключение..." && when_ok
    print_line
    docker_exec "${container_id_running}" "${script_to_run}" "${_user}" "${arch}"
}


#-------------------------------------------------------------------------------
# Подключаемся к контейнеру когда он уже остановлен, но существует
#-------------------------------------------------------------------------------
connect_when_stopped(){

    script_to_run=${1}
    run_with_root=${2}
    container_id_exited=${3}
    arch=${4}
    container_name=${5}
    _user=${USER}

    [ "${run_with_root}" = yes ] && _user=root
    ready  "${PREF}Контейнер разработки ${BLUE}${container_name}${NOCL} смонтирован, но..." && when_err "ОСТАНОВЛЕН"
	ready "${PREF}Монтируем контейнер..."
	docker start "${container_id_exited}" >/dev/null 2>&1 && when_ok || when_err "ОШИБКА" "$(get_container_log \"${container_id_exited}\")"
    print_line
    print_warning "${PREF}Заходим внутрь контейнера..."
    docker_exec "${container_id_exited}" "${script_to_run}" "${_user}" "${arch}"

}

#-------------------------------------------------------------------------------
# Подключаемся к контейнеру, когда он не существует (не смонтирован)
#-------------------------------------------------------------------------------
connect_when_not_mounted(){

    script_to_run=${1}
    run_with_root=${2}
    arch=${3}
    container_name=${4}
    _user=${USER}

    [ "${run_with_root}" = yes ] && _user=root
    ready "${PREF}Контейнер ${BLUE}${container_name}${NOCL}" && when_ok "ЕЩЕ НЕ СОЗДАН"


    user_group_id="${U_ID}:${G_ID}"
    [ -z "${script_to_run}" ] && [ "${run_with_root}" = yes ] && user_group_id="root:root";
#   а если контейнера нет - то создаем его и запускаем
	ready  "${PREF}Создаем контейнер. Ожидайте, займет некоторое время..."
	docker_run "" "${container_name}" "${arch}" "${user_group_id}" && when_ok || when_err
	container_id=$(docker ps -qa  --filter name="${container_name}")

	ready "${PREF}Монтируем контейнер ${BLUE}${container_name}${NOCL}..."

	docker start "${container_id}" &> /dev/null && when_ok || when_err
	print_info "Заходим внутрь контейнера"
	print_line
	docker_exec  "${container_id}" "${1}" "${_user}" "${arch}"
#    fi

}

#-------------------------------------------------------------------------------
# Собираем образ для запуска контейнера
#-------------------------------------------------------------------------------
build_image(){

    ready "Запускаем сборку НОВОГО образа ${BLUE}${IMAGE_NAME}${NOCL}"

	# Создаем их, если не существуют
	set_user_group_for_path "${APPS_ROOT}/${APP_NAME}" "${USER}" "${U_ID}" "${GROUP}" "${G_ID}"

    context="$(dirname "$(pwd)")/"
    docker build \
        --tag "${IMAGE_NAME}" \
        --build-arg UID="${U_ID}" \
        --build-arg GID="${G_ID}" \
        --build-arg USER="${USER}" \
        --build-arg GROUP="${GROUP}" \
        --build-arg APPS_ROOT="${APPS_ROOT}" \
        --build-arg APP_NAME="${APP_NAME}" \
        --build-arg TZ=Europe/Moscow \
        --file "${DOCKER_FILE}" \
        "${context}" >/dev/null 2>&1 && when_ok || {
        	when_err "ПРОБЛЕМА"  "$(get_container_log "${IMAGE_NAME}")"
        }
#
#        print_line
#        print_info "${PREF}Docker-образ собран без ошибок."
#
#    else
#    	error="${PREF}В процессе сборки Docker-образа '${IMAGE_NAME}' возникли ошибки."
#    	run_when_error "${IMAGE_NAME}" "${error}"
#        exit 1
#    fi
    print_line
    exit
}


#-------------------------------------------------------------------------------
# Удаляем готовый образ и собираем его заново для запуска контейнера
#-------------------------------------------------------------------------------
rebuild_image(){


    script_to_run=${1}

	ready "${PREF}Удаляем предыдущий образ ${BLUE}${IMAGE_NAME}${NOCL}"
	{
		container_id_exited=$(docker ps --filter ancestor="${IMAGE_NAME}" -q)
		if [ -n "${container_id_exited}" ] ; then
			purge_containers "${container_id_exited}" &>/dev/null
		else
			container_id_exited=$(docker ps -a --filter ancestor="${IMAGE_NAME}" -q)
			[ -n "${container_id_exited}" ] && docker rm ${container_id_exited} &> /dev/null
		fi

		get_image_id && docker rmi -f "${IMAGE_NAME}" &>/dev/null

	}  && when_ok || when_err

	build_image
}

#-------------------------------------------------------------------------------
# Подключаемся к контейнеру для сборки приложения в нем
#-------------------------------------------------------------------------------
container_run_to_make(){
    script_to_run="${1}"
    run_with_root="${2}"
    arch=${3}
    container_name="$(get_container_name "${arch}")"

    if [ "${run_with_root}" = yes ]; then _user=root; else _user=${USER}; fi
    container_id_up=$(docker ps -q --filter name="${container_name}")
    if [ -n "${container_id_up}" ]; then
        connect_when_run "${script_to_run}" "${run_with_root}" "${container_id_up}" "${arch}" "${container_name}"
    else
        container_id_down=$(docker ps -qa  --filter name="${container_name}" --filter status=exited)
        if [ -n "${container_id_down}" ]; then
            connect_when_stopped "${script_to_run}" "${run_with_root}" "${container_id_down}" "${arch}" "${container_name}"
        else
            if [ -n "$(get_image_id)" ]; then
                connect_when_not_mounted "${script_to_run}" "${run_with_root}" "${arch}" "${container_name}"
            else
                build_image && {
                	print_warning "${PREF}Запускаем сборку пакета в контейнере '${container_name}' ..."
                	print_line
                	container_manager_to_make "${script_to_run}" "" "${arch}"
                }

            fi
        fi
    fi

}

#-------------------------------------------------------------------------------
# Отображаем меню с запросом об архитектуре сборки
#-------------------------------------------------------------------------------
ask_arch_to_run(){
#set -x
	list_arch=${1}
	script_to_run=${2}
	choice=${3}
	extra_menu_pos="Все\tархитектуры"

	list_arch_menu=${list_arch};

	if [ -n "${script_to_run}" ]; then
		if [ "${script_to_run}" = remove ] ; then
			act="${RED}удаления${NOCL}";
			list_arch_menu="$(get_container_list) ${extra_menu_pos}";
		else
			act="${GREEN}сборки${NOCL}";
			list_arch_menu="${list_arch} ${extra_menu_pos}";
		fi
	else act="${BLUE}терминала${NOCL}"; fi

	print_info "Доступные ${BLUE}архитектуры${NOCL} для ${act} [Q/q - выход]:"
	print_line
	count=1; #container_list=$(get_container_list)
	for _arch_ in ${ARCH_LIST} ; do

		if echo "${_arch_}" | grep -Eq '\*'; then
			ready " ${count}. ${BLUE}${_arch_//\*/}${NOCL}"
			when_ok "СМОНТИРОВАН"
		else
			if [ "${script_to_run}" = remove ] ; then
				if echo "${list_arch_menu}" | grep -q "${_arch_}" ; then
					ready " ${count}. ${BLUE}${_arch_//\*/}${NOCL}"
					when_ok "ОСТАНОВЛЕН" "${BLUE}"
				else
					count=$((count-1))
				fi
			else
				ready " ${count}. ${BLUE}${_arch_//\*/}${NOCL}"
				if echo "${list_arch_menu}"  | grep -q "${_arch_}" ; then
					when_ok "ОСТАНОВЛЕН" "${BLUE}"
				else
					when_err "НЕ СОЗДАН"
				fi
			fi
		fi
		count=$((count+1))
	done
	print_line
	read_choice "Выберите номер позиции из списка: " "${count}" choice
	print_line
}


#-------------------------------------------------------------------------------
# Печатаем заголовок для очередной сборки архитектуры
#-------------------------------------------------------------------------------
print_header(){

	arch=$(printf "${1}" | awk '{print toupper($0)}')
	user=$(printf "${2}" | awk '{print toupper($0)}')
	app=$(printf "${APP_NAME}" | awk '{print toupper($0)}')

#	echo ""
#	echo ""

	print_info "		ПОЛЬЗОВАТЕЛЬ: ${GREEN}${user}${NOCL}"
	print_info "		       ПАКЕТ: ${GREEN}${app}${NOCL}"
	print_info "		 АРХИТЕКТУРА: ${GREEN}${arch}${NOCL}"
#
#	echo ""
#	echo ""
	print_line
}

#-------------------------------------------------------------------------------
# Подключаемся к контейнеру для сборки приложения в нем
#-------------------------------------------------------------------------------
container_manager_to_make(){
#set -x
	script_to_run="${1}"
	run_with_root="${2:-no}"
	arch_to_run=${3}
	count=0; choice=''
	extra_menu_pos="Все\tархитектуры"

	[ "${run_with_root}" = yes ] && _user=root || _user=${USER}

    if is_mac_os_x ; then
        ps -x | grep 'Docker.app' | grep -vq grep || {
            print_error "${PREF}Сервис Docker не запущен! Для запуска наберите команду 'open -a Docker'"
            print_line
            exit 1
        }
    fi
#    если язык разработки Shell
    if [ "${DEVELOP_EXT}" = bash ] ; then

    	print_header "BASH" "${_user}"
		print_line
        container_run_to_make "${script_to_run}" "${run_with_root}" "$(get_container_name "all")" "all"
    else
#		если язык разработки Си или С++
#		if [ -n "${script_to_run}" ] ; then
		list_arch="$(get_arch_list | awk '{print tolower($0)}')"
#		else
#			list_arch="$(get_container_list | awk '{print tolower($0)}')"
#		fi

#    	если указанная архитектура присутствует в списке
		list_size=$(echo "${list_arch}" | grep -cE '^[a-zA-Z]')

		if [ -z "${arch_to_run}" ]; then
#        	если не задана архитектура сборки - запрашиваем ее
			ask_arch_to_run "${list_arch}" "${script_to_run}" choice
		else
			if [ "${arch_to_run}" = all ]; then
#        		если архитектура - all
				if [ -n "${script_to_run}" ] ; then
					choice=$(( list_size + 1))
				else
#					если был задан аргумент all в режиме терминала (например по забывчивости)
					ask_arch_to_run "${list_arch}" "${script_to_run}" choice
				fi
			else
#        		если указана в аргументах конкретная архитектура
				choice=$(echo "${list_arch}" | grep -n "${arch_to_run}" | head -1 | cut -d':' -f1)
				if [ -z "${choice}" ] ; then
					print_error "${PREF}Неверно указана архитектура для запуска контейнера!"
					print_line
					ask_arch_to_run "${list_arch}" "${script_to_run}" choice
				fi
			fi
		fi

		if [ "${choice}" = q ] ; then exit 1;
		else

			if [ "${choice}" -gt "${list_size}" ] && [ -n "${script_to_run}" ]; then
				num=1;
	#       	в случае если выбран крайний пункт в списке и это пункт "Все\tархитектуры", то..
				for _arch in ${list_arch}; do
					[ "${num}" -le "${list_size}" ] && print_header "${_arch}" "${_user}"
					container_run_to_make "${script_to_run}" "${run_with_root}" "${_arch}"

					num=$((num + 1))
				done
			else
				arch=$(echo "${list_arch}" | tr '\n' ' ' | tr -s ' ' | cut -d' ' -f"${choice}")
#				arch=${arch//\*/}
				print_header "${arch}" "${_user}"
				container_run_to_make "${script_to_run}" "${run_with_root}" "${arch}"
			fi
		fi

    fi


}

#-------------------------------------------------------------------------------
# Выводим или устанавливаем версию собираемого пакета
#-------------------------------------------------------------------------------
package_version_set(){

    ver_to_set=$(echo "${1}" | tr ' !|~' '-')

    if [ -n "${ver_to_set}" ] ; then
        ver_main="$(echo "${ver_to_set}" | tr -d 'a-zA-Z' | cut -d '-' -f1) "

        if [ -z "$(echo "${ver_main}" | tr -d ' ')" ]; then
            print_error "${PREF}Данные о версии пакета введены некорректно!"
        else
            if echo "${ver_to_set}" | grep -q '-' ; then
                ver_stage="$(echo "${ver_to_set}" | cut -d '-' -f2 | tr -d '0-9') "
                if [ -z "${ver_stage}" ]; then pos=2; else pos=3; fi
                ver_release=$(echo "${ver_to_set}" | cut -d '-' -f"${pos}")
                if [ -z "${ver_release}" ]; then ver_stage=${ver_stage// /}; fi
            else
                ver_stage=''; ver_release=''
            fi
            full_ver=$(echo "${ver_main}${ver_stage}${ver_release}" | sed -e 's/[[:space:]]*$//' | tr ' ' '-')
            ready "${PREF}Версия пакета '${full_ver}' установлена..."
            {
				[ -z "${ver_stage}" ] && ver_main=${ver_main// /}
				set_version_part "PACKAGE_VERSION"  "${ver_main}"
				set_version_part "PACKAGE_STAGE"    "${ver_stage}"
				set_version_part "PACKAGE_RELEASE"  "${ver_release}"
				full_ver=$(echo "${ver_main}${ver_stage}${ver_release}" | sed -e 's/[[:space:]]*$//' | tr ' ' '-')
			} && when_ok || when_err

        fi
    else
        ver_main="$(get_version     "PACKAGE_VERSION")"
        ver_stage="$(get_version    "PACKAGE_STAGE")"
        ver_release="$(get_version  "PACKAGE_RELEASE")"
        full_ver=$(echo "${ver_main}${ver_stage}${ver_release}" | sed -e 's/[[:space:]]*$//' | tr ' ' '-')
        ready "${PREF}Текущая версия пакета " && when_ok "${full_ver}"
    fi
    print_line
}

#-------------------------------------------------------------------------------
# Удаляем контейнер с заданной в аргументе архитектурой
#-------------------------------------------------------------------------------
remove_arch_container(){

	dc_name=${1//\*/};
	[ -z "${2}" ] && list_dc=$(get_container_list) || list_dc="${2//\*/}"

	if echo "${list_dc//\*/}" | grep -q "${dc_name}" ; then
		ready "${PREF}Удаляем контейнер c архитектурой ${dc_name}..."
		container_id=$(get_container_id "${dc_name}")
		purge_containers "${container_id}" &>/dev/null && when_ok "УСПЕШНО" || when_err "С ОШИБКАМИ"
	else
		print_warning "Контейнер с архитектурой не существует ${dc_name}" && when_err "пропускаем"
	fi
}
#-------------------------------------------------------------------------------
# Удаляем контейнер с заданной в аргументе архитектурой
#-------------------------------------------------------------------------------
manage_to_remove_arch_container(){
#set -x
	arch_build=${1}; choice=''

	if [ "${arch_build}" ]; then
#		 в случае, если архитектура задана
		list_arch=$(get_container_list)
	    if echo "${list_arch}" | sed "s/^${APP_NAME}-\(.*\)/\1/" | grep -qE "^${arch_build}-" ; then
#	    	в случае, если архитектура распознана
	        remove_arch_container "${arch_build}"
	    else
	    	list_size=$(echo "${list_arch}" | grep -cE '^[*a-zA-Z]')
	    	if [ "${list_size}" -ge 0 ]; then
				if [ "${arch_build}" = all ]; then
	#        		если архитектура - all
					choice=$(( list_size + 1))
				else
	#        		если указана в аргументах конкретная архитектура
					choice=$(echo "${list_arch}" | grep -n "${arch_build}" | head -1 | cut -d':' -f1)
					if [ -z "${choice}" ] ; then
						[[ "${arch_build}" =~ remove|rm|del|-rm ]] || {
							print_error "${PREF}Неверно указана архитектура для УДАЛЕНИЯ!";
							print_line
						}
						if [ "${list_size}" = 1 ]; then
							choice=1
						else
							ask_arch_to_run "${list_arch}" "remove" choice
						fi
					fi
				fi
#				Обработка выбора
				if [ "${choice}" = q ] ; then exit 1; # выход если нажали Q
				else
	#				если выбрали из списка
					if [ "${choice}" -gt "${list_size}" ]; then
	#					если выбрали элемент "Все\tархитектуры"
						num=1;
						for _arch in ${list_arch}; do
							if echo "${list_dc}" | grep -q "${_arch}" ; then
	#							если такой контейнер был ранее создан
								remove_arch_container "${_arch}" "${list_dc}"
							else
								print_warning "Контейнер с архитектурой не существует ${_arch}" && when_err "пропускаем"
							fi
							num=$((num + 1))
						done
					else
	#					если выбрали конкретный вариант архитектуры
						arch=$(echo "${list_arch}" | tr '\n' ' ' | tr -s ' ' | cut -d' ' -f"${choice}")
						if echo "${list_arch}" | grep -q "${arch}" ; then
	#						если такой контейнер был ранее создан
							remove_arch_container "${arch}" "${list_arch}"
						else
							print_warning "Контейнер с архитектурой не существует ${arch}" && when_err "пропускаем"
						fi
					fi
				fi
			else
				ready "${PREF}Контейнеры для сборки" && when_err "ОТСУСТВУЮТ!"
			fi
	    fi
	else
		ready "${PREF}При удалении архитектура сборки" && when_err "НЕ ЗАДАНА!"
	fi
	print_line

}
#-------------------------------------------------------------------------------
# Проверяем был ли в аргументах передан флаг отладки
#-------------------------------------------------------------------------------
set_debug_status(){
    if [[ "${*}" =~ -vb|debug|-v|-deb ]] ; then debug=YES; else debug=NO; fi
    sedi "s|DEBUG=.*$|DEBUG=${debug}|" ./package.app
    echo "${*}" | sed "s/debug//g; s/-vb//g; s/-v//g;" | tr -d ' '
}

#-------------------------------------------------------------------------------
# Обновляем из github репозитория настоящий пакет
#-------------------------------------------------------------------------------
update_me(){
	ready "${PREF}Обновление пакета 'Котомка' завершено..."
	{
		tmp_path="../../.tmp-update"
		rm -rf "${tmp_path}" && mkdir "${tmp_path}" && cd "${tmp_path}" || exit 1
		curl "https://codeload.github.com/qzeleza/${PACKAGE_APP_NAME}/zip/refs/heads/main" -o "./${PACKAGE_APP_NAME}.zip" &>/dev/null
		unzip "./${PACKAGE_APP_NAME}.zip" &>/dev/null
		app_path=$(find . -type d -name "${PACKAGE_APP_NAME}-*" | head -1)
		cd "${app_path}/" && ls | grep -v run | xargs rm  -rf || exit 1
		cd "${tmp_path}" || exit 1
		cp -rf "${app_path}/." "../" || exit 1
		cd .. && rm -rf "./$(basename "${tmp_path}")" || exit 1
	} && when_ok "удачно!" || when_err "с ошибками!"
	print_line
}
#-------------------------------------------------------------------------------
# Удаляем готовый образ и собираем его заново для запуска контейнера
#-------------------------------------------------------------------------------
show_help(){

    print_line
    print_warning " Котомка [kotomka] - скрипт предназначенный для быстрого развертывания среды разработки Entware"
    print_warning " в Docker-контейнере для роутеров Keenetic с целью сборки пакетов на языках семейства Bash, С, С++."
    print_line
    print_warning " Аргументы одиночные:"
    print_line
    echo " build    		[-bl] - сборка образа на основании которого будут собираться контейнеры."
    echo " rebuild  	    	[-rb] - удаляем готовый образ и собираем его заново."
    echo " version|ver   		[-vr] - отображаем текущую версию собираемого пакета"
    echo " version <N>		      - устанавливаем версию собираемого пакета, где номер в формате"
    echo "                  	    	<N-stage-rel>, гду N - номер версии, например 1.0.12"
    echo "                  	    	stage - стадия разработки [alpha, betta, preview]"
    echo "                  	    	rel - выпускаемый номер релиза, например 01"
	print_line
    echo " make     		[-mk] - сборка пакета и копирование его на роутер"
	echo " make debug|deb       	      - сборка пакета в режиме отладки."
    echo " copy|install	[-cp|-in] - копирование уже собранного пакета на роутер"
    echo " term     	   	[-tr] - подключение к контейнеру под пользователем '${USER}'."
    echo " root     	   	[-rt] - подключение к контейнеру под пользователем 'root'"
    echo " test     	   	[-ts] - запуск тестов на удаленном устройстве. "
    echo " reset    	   	[-rs] - cбрасываем пакет в состояние до установки языка разработки."
    echo " update			[-up] - обновляем из github данный проект."
    echo " help     	   	[-hl] - отображает настоящую справку"
    print_line
    echo -e " ${BLUE}Аргументы с заданной архитектурой:${NOCL}"
    print_line
    echo " <arch> make 		[-mk] - сборка пакета и копирование его на роутер для указанной архитектуры,"
    echo "                  	    	где arch может принимать следующие значения: ."
    echo "                  		all - для всех типов архитектур в файле конфигурации '${DEV_CONFIG_NAME}'."
    echo "                  		aarch64 - для ARCH64 архитектуры, "
    echo "                  		mips - для MIPS архитектуры "
    echo "                  		mipsel - для MIPSEL архитектуры"
    echo "                  		armv5  - для ARMv5 архитектуры"
    echo "                  		armv7-2.6 - для ARMv7 версии 2.6 архитектуры"
	echo "                  		armv7-3.2 - для ARMv7 версии 3.2 архитектуры"
    echo "                  		x64  - для X64 архитектуры"
    echo "                  		x86  - для X86 архитектуры"
    echo " <arch> copy|install   - копирование уже собранного пакета, указанной архитектуры на роутер."
    echo " <arch> remove		[-rm] - производим удаление контейнера."
	echo " <arch> term 		[-tr] - подключение к контейнеру под пользователем ${USER} для arch архи-ры."
	echo " <arch> root 		[-rt] - подключение к контейнеру под пользователем root для arch архи-ры."
    print_line
    echo -e " Примеры запуска:"
    print_line
    echo  " ./build.run mips make 	      - запускаем сборку пакета для платформы mips."
    echo  " ./build.run mipsel rm        - удаляем контейнер для платформы mips."
    echo  " ./build.run build            - запускаем сборку образа среды разработки, который служит основанием"
    echo  "                                для контейнеров всех заданных архитектур в файле конф-ции ./build.conf"
    echo  " ./build.run make debug       - запускаем сборку с опцией отладки и выбрираем из диалога архи-ру."
    echo  " ./build.run mipsel copy      - копируем, ранее собранный пакет на удаленное устройство с mipsel."
    echo  " ./build.run mipsel term      - заходим в ранее собранный контейнер под именем master с mipsel."
	echo  " ./build.run term	      - заходим в ранее собранный контейнер под именем разработчика,"
	echo  " 			        но в отличии от варианта выше, выбрираем из диалога архи-ру запуска."
    print_line
}

print_line
prepare_code_structure

args="$(set_debug_status "${*}")"

#   Сбрасываем в первоначальное состояние пакет до установки языка разработки
if [[ "${args}" =~ reset|-rs ]] ; then
    reset_data;
    exit 0;
else
    [[ "${args}" =~ rebuild|-rb ]] && {
    	reset_data
    	prepare_code_structure
    }
    check_dev_language
fi

arg_1=$(echo "${1}" | cut -d' ' -f1)
arg_2=$(echo "${1}" | cut -d' ' -f2)

case "${arg_1}" in
	build|-bl) 				  				build_image; exit 0 ;;
    rebuild|-rb)            				rebuild_image "${SCRIPT_TO_MAKE}"; exit 0  ;;
	update|-ud|-up)							update_me; exit 0  ;;
    help|-h|--help)         				show_help; exit 0 ;;
	version|ver|-vr)						package_version_set "$(echo "${arg_2//ver/}" | sed -e 's/^[[:space:]]*//')"; exit 0  ;;
	*)    									;;
esac

case "${arg_2}" in

	term|user|-tr ) 	[ -n "${arg_1}" ] && 		container_manager_to_make "" "" "${arg_1}" ;;
	root|admin|-rt) 	[ -n "${arg_1}" ] && 		container_manager_to_make "" "yes" "${arg_1}" ;;
	make|-mk)								container_manager_to_make "${SCRIPT_TO_MAKE}" "" "${arg_1}" ;;
	copy|install|-cp|-in )  	        	container_manager_to_make "${SCRIPT_TO_COPY}" "" "${arg_1}" ;;
    test|-ts )  	        				container_manager_to_make "${SCRIPT_TO_TEST}" "" "${arg_1}" ;;
	remove|rm|del|-rm)						manage_to_remove_arch_container "${arg_1}";;

	*)
											print_error "${PREF}Аргументы запуска скрипта не заданы, либо не верны!";
                            				show_help
    ;;
esac
