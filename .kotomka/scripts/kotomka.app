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
PREF='>> '
SEP=

DEV_NAME_PATH=.kotomka
PATH_PREFIX="../."
DEV_CONFIG_NAME=build.conf
DEV_CONFIG_FILE="../../${DEV_CONFIG_NAME}"
DEVELOP_EXT=''

. "${DEV_CONFIG_FILE}"
. ./library "${PATH_PREFIX}."

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
# Экранируем символы '/' в строке для передачи в sed
#-------------------------------------------------------------------------------
escape()(echo "${1}" | sed 's|\/|\\/|g')

#-------------------------------------------------------------------------------
# Получаем необходимую информацию о версии пакета
#-------------------------------------------------------------------------------
get_version_part(){
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
PACKAGE_VERSION=$(get_version_part PACKAGE_VERSION)
PACKAGE_STAGE=$(get_version_part PACKAGE_STAGE)
PACKAGE_RELEASE=$(get_version_part PACKAGE_RELEASE)
#-------------------------------------------------------------------------------
FULL_VERSION="${PACKAGE_VERSION} ${PACKAGE_RELEASE}";
[ -n "${PACKAGE_STAGE}" ] && FULL_VERSION="${PACKAGE_VERSION} ${PACKAGE_STAGE} ${PACKAGE_RELEASE}";
#-------------------------------------------------------------------------------

DEBUG=YES # флаг отладки процесса сборки образа
#-------------------------------------------------------------------------------
APP_NAME=$(pwd | sed "s/.*\\${APPS_ROOT}\/\(.*\).*$/\1/;" | cut -d'/' -f1)
IMAGE_NAME=$(echo "${DOCKER_ACCOUNT_NAME}" | tr "[:upper:]" "[:lower:]")/${APP_NAME}-dev

#-------------------------------------------------------------------------------
#	Пути к файлам на машине разработчика
#-------------------------------------------------------------------------------
DOCKER_FILES_PATH=../docker
DOCKER_FILE=${DOCKER_FILES_PATH}/Dockerfile

#-------------------------------------------------------------------------------
#	Пути к файлам внутри контейнера
#-------------------------------------------------------------------------------
SCRIPTS_PATH=${APPS_ROOT}/${APP_NAME}/${DEV_NAME_PATH}/scripts
SCRIPT_TO_MAKE=${SCRIPTS_PATH}/package.app
SCRIPT_TO_COPY=${SCRIPTS_PATH}/copy.app
SCRIPT_TO_TEST=${SCRIPTS_PATH}/testsrun.app
WORK_PATH_IN_CONTAINER="${APPS_ROOT}/${APP_NAME}/${DEV_NAME_PATH}"

#-------------------------------------------------------------------------------
#  Формируем имя контейнера в зависимости от архитектуры процессора.
#-------------------------------------------------------------------------------
get_container_name()(echo "${APP_NAME}-${1}" | tr "[:upper:]" "[:lower:]")


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
    	show_line
    	rm -rf "${PATH_PREFIX}${DEV_ROOT_PATH}"
		purge_containers "$(docker ps -aq -f name="${APP_NAME}")" &>/dev/null
		echo -e "${PREF}Пакет сброшен в первоначальное состояние.${NOCL}"
		echo -e "${PREF}Папка с исходниками ${RED}${DEV_ROOT_PATH}${NOCL} удалена!${NOCL}"
		echo -e "${PREF}Удалены все контейнеры приложения ${RED}${APP_NAME}${NOCL}!${NOCL}"
		show_line
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

    make_file="${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_COMPILE_NAME}/Makefile"

    sed -i "${SEP}" "s/@APP_NAME/$(escape "${APP_NAME}")/g; \
         s/@PACKAGE_VERSION/$(escape "${PACKAGE_VERSION}" | tr -d ' ')/g; \
         s/@PACKAGE_STAGE/$(escape "${PACKAGE_STAGE}" | tr -d ' ')/g; \
         s/@APP_ROUTER_DIR/${app_router_dir}/g; \
         s/@PACKAGE_RELEASE/$(escape "${PACKAGE_RELEASE}")/g; \
         s/@LICENCE/$(escape "${LICENCE}")/g; \
         s/@AUTHOR/$(escape "${AUTHOR_NAME}")/g; \
         s/@EMAIL/$(escape "${AUTHOR_EMAIL}")/g; \
         s/@GITHUB/${github_url}/g; \
         s/@CATEGORY/$(escape "${PACKAGE_CATEGORY}")/g; \
         s/@SUBMENU/$(escape "${PACKAGE_SUBMENU}")/g; \
         s/@TITLE/$(escape "${PACKAGE_TITLE}")/g; \
         s/@SOURCE_DIR/${source_dir}/g; \
         s/@CODE_DIR/${code_dir}/g;" "${make_file}"

    awkfun -i inplace -v r="${PACKAGE_DESCRIPTION}" '{gsub(/@DESCRIPTION/,r)}1' "${make_file}"

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
        name=$(echo "${name_caps}" | tr "[:upper:]" "[:lower:]")

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
	case "$(echo "${DEV_LANGUAGE}" | tr "[:upper:]" "[:lower:]")" in
		си|c|cc|сс|ccc|ссс)
			DEVELOP_EXT='c'				# на английском
			lang="Си"					# на русском
			;;
		с++|cpp|c++|срр)
			DEVELOP_EXT='cpp'			# на английском
			lang="С++"					# на английском
			;;
		bash|sh|shell)
			DEVELOP_EXT='bash'			# на английском
			lang="Bash"
			;;
	esac

    echo -e "${BLUE}${PREF}Заявленным языком разработки является '${lang}'${NOCL}"
    echo -e "${BLUE}${PREF}Производим замену файлов в соответствии с установками в ${DEV_CONFIG_NAME} ${NOCL}"
    show_line

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
            show_line
            echo -e "${RED}${PREF}Не распознан язык разработки в файле ${DEV_CONFIG_FILE}${NOCL}"
            echo -e "${BLUE}${PREF}Текущее значение DEV_LANGUAGE = ${DEV_LANGUAGE}.${NOCL}"
            echo -e "${BLUE}${PREF}Задайте одно из значений: C (Си), CPP (C++) или BASH.${NOCL}"
            echo -e "${BLUE}${PREF}Значения можно задавать на русском или английском.${NOCL}"
            show_line
            exit 1
            ;;
    esac

    manifest_scripts_path="${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_COMPILE_NAME}${DEV_MANIFEST_DIR_NAME}"
#   создаем скрипты для сборки файла манифеста
    mkdir_when_not "${manifest_scripts_path}"

#   и копируем сам файл манифеста
    makefile_path="${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_COMPILE_NAME}/${arch}"
    mkdir_when_not "${makefile_path}"
    cp -f "../templates/compile/Manifest.${DEVELOP_EXT}"     "${makefile_path}Makefile"

    #   создаем секции манифеста и файлы для них
    create_sections "${manifest_scripts_path}"
    sedi '/^[[:space:]]*$/d' "${makefile_path}Makefile"

	prepare_makefile

#   меняем имя пакета в файле для удаленных тестов
    tests_path="${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_TESTS_NAME}"
    cp -rf "../templates/tests/" "${tests_path}"
    sedi "s|@APP_NAME|${APP_NAME}|g"                    "${tests_path}/modules/hello.bats"
}


#-------------------------------------------------------------------------------
#  Проверяем соответствия флага языка разработки и текущий манифест для сборки пакета
#-------------------------------------------------------------------------------
check_dev_language(){

    manifest_file=$(find ../.. -type f | grep "${DEV_COMPILE_NAME}/${arch}Makefile" | head -1)

    if [ -n "${manifest_file}" ]; then
        if ! cat < "${manifest_file}" | grep -qi "для ${DEVELOP_EXT}"; then
            echo -e "${RED}${PREF}Обнаружено несоответствие файлов проекта с заявленным${NOCL}"
            echo -e "${RED}${PREF}языком разработки для архитектуры процессора ${BLUE}${PREF}${arch}${NOCL}"
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

    mkdir_when_not  "${PATH_PREFIX}${DEV_ROOT_PATH}"
    mkdir_when_not  "${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_SRC_PATH}"

#   создаем папку с тестами
    tests_path="${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_TESTS_NAME}"
    [ -n "${DEV_TESTS_NAME}" ] && ! [ -d "${tests_path}" ] && {
        mkdir_when_not "${tests_path}"
        cp -rf "../templates/tests/" "${tests_path}"
        sedi "s|@APP_NAME|${APP_NAME}|g"                    "${tests_path}/modules/hello.bats"
    }
#   создаем папку /opt с минимальной структурой, как на устройстве
    opt_path="${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_OPT_PATH}"
    [ -n "${DEV_OPT_PATH}" ] && ! [ -d "${opt_path}" ] && {
        mkdir -p "${opt_path}/etc" "${opt_path}/bin" "${opt_path}/etc/init.d"
        mkdir -p "${opt_path}/etc/ndm/netfilter.d" "${opt_path}/etc/ndm/ifstatechanged.d"
        mkdir -p "${opt_path}/etc/ndm/fs.d" "${opt_path}/etc/ndm/wan.d"
    }
#   создаем папку /packages
    if [ -n "${DEV_IPK_NAME}" ] && ! [ -d "${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_IPK_NAME}" ]; then
        mkdir -p "${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_IPK_NAME}"
    fi

    if ! [ -d "${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_COMPILE_NAME}/" ]; then
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
            echo -e "${BLUE}${PREF}Производим установку недостающего пакета 'gawk' для 'Mac OS X'${NOCL}"
            show_line
            brew install gawk
        fi
        SEP=''
    fi

}


#-------------------------------------------------------------------------------
#  Получаем ID контейнера
#-------------------------------------------------------------------------------
get_container_id(){
    container_name=${1}
	container_id_exited=$(docker ps | grep "${container_name}" | head -1 | cut -d' ' -f1 )
	[ -z "${container_id_exited}" ] && container_id_exited=$(docker ps -a | grep "${container_name}" | head -1 | cut -d' ' -f1 )
	echo "${container_id_exited}"
}


#-------------------------------------------------------------------------------
#  Останавливаем и удаляем контейнер
#-------------------------------------------------------------------------------
purge_containers(){
	container_id="${1}"
	docker stop ${container_id}
	docker rm ${container_id}
}


#-------------------------------------------------------------------------------
#  Запускаем в случае, если при запуске контейнера произошла ошибка
#-------------------------------------------------------------------------------
run_when_error(){

	container_id_or_name=$(echo "${1}" | tr "[:lower:]" "[:upper:]")
	error_tag="${RED}ОШИБКА${NOCL}"

	show_line;
	echo -e "${error_tag} ${PREF}${BLUE}В ПРОЦЕССЕ СБОРКИ ПАКЕТА ВОЗНИКЛИ ОШИБКИ${NOCL}"
	echo -e "${error_tag} ${PREF}${BLUE}ЖУРНАЛ КОНТЕЙНЕРА ОБОЗНАЧЕН НИЖЕ:${NOCL}"
	print_line_sim '='
	print_line_sim '⬇'
	print_line_sim "-"
	echo -e "${YELLOW}"
	docker logs "${1}" --details --tail 50
	echo -e "${NOCL}"
	print_line_sim "-"
	print_line_sim '⬆'
	print_line_sim '='
	echo -e "${error_tag} ${PREF}${BLUE}КОНЕЦ ЖУРНАЛА КОНТЕЙНЕРА ${container_id_or_name}${NOCL}"
	show_line
	echo
}
#-------------------------------------------------------------------------------
#  Запускаем Docker exec с параметрами
#   $1 - container_id_exited
#   $2 - скрипт для запуска внутри контейнера сразу после входа в него
#   $3 - root, если пусто, то входим под именем текущего пользователя
#   $4 - архитектура процессора
#-------------------------------------------------------------------------------
docker_exec(){

    container_id_exited=${1};
    script_to_run=${2};
    root=${3};
    arch_build=$(echo "${4}" | tr "[:upper:]" "[:lower:]")

    if [ "${root}" = root ]; then user="root:root"; else user="${USER}:${GROUP}"; fi
    if [ -z "${script_to_run}" ]; then WORK_PATH_IN_CONTAINER="${APPS_ROOT}/entware"; fi
    docker exec \
			--interactive --tty  \
			--workdir "${WORK_PATH_IN_CONTAINER}" \
			--env ROUTER_LIST="${ROUTER_LIST}" \
			--env COMPILE_NAME="${DEV_COMPILE_NAME}" \
			--env ROOT_PATH="${DEV_ROOT_PATH//.\//}" \
			--env OPT_PATH="${DEV_OPT_PATH}" \
           	--env SRC_PATH="${DEV_SRC_PATH}" \
           	--env ARCH_BUILD="${arch_build}" \
           	--env IPK_PATH="${DEV_IPK_NAME}" \
           	--user "${user}" \
           	 "${container_id_exited}" /bin/bash ${script_to_run} || {
           	 	container_name=$(docker ps -a -f id=${container_id_exited} --format "{{.Names}}")
				run_when_error "${container_name}"
               	exit 1
        }
}

#-------------------------------------------------------------------------------
#  Запускаем Docker run с параметрами
#   $1 - скрипт для запуска внутри контейнера сразу после входа в него
#   $2 - имя контейнера
#   $3 - архитектура процессора
#-------------------------------------------------------------------------------
docker_run(){

    script_to_run=${1};
    container_name=${2};
    arch_build=$(echo "${3}" | tr "[:upper:]" "[:lower:]")
    user=${4}
    context=$(dirname "$(dirname "$(pwd)")")

    if [ -n "${container_name}" ] ; then name_container="--name ${container_name}"; else name_container=""; fi
 	if [ -z "${script_to_run}" ]; then WORK_PATH_IN_CONTAINER="${APPS_ROOT}/entware"; fi

    docker run \
           	--interactive --tty \
           	--workdir "${WORK_PATH_IN_CONTAINER}" \
			--env ROUTER_LIST="${ROUTER_LIST}" \
           	--env ARCH_BUILD="${arch_build}" \
           	--env COMPILE_NAME="${DEV_COMPILE_NAME}" \
			--env ROOT_PATH="${DEV_ROOT_PATH//.\//}" \
			--env OPT_PATH="${DEV_OPT_PATH}" \
           	--env SRC_PATH="${DEV_SRC_PATH}" \
		   	--env IPK_PATH="${DEV_IPK_NAME}" \
		   	--env TZ=Europe/Moscow \
           	--user "${user}" \
           	${name_container} \
           	--mount type=bind,src="${context}",dst="${APPS_ROOT}"/"${APP_NAME}" \
           	"$(get_image_id)" /bin/bash ${script_to_run} || {
				run_when_error "${container_name}"
               	exit 1
           }
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

   	echo -e "${PREF}${_user}::Контейнер разработки '${container_name}' ${BLUE}ЗАПУЩЕН${NOCL}."
    echo "${PREF}${_user}::Производим подключение к контейнеру..."
	echo -e "${PREF}ЗАХОДИМ ВНУТРЬ КОНТЕЙНЕРА '${GREEN}${container_name}${NOCL}'"
    show_line
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
    echo -e "${PREF}${_user}::Контейнер разработки '${container_name}' смонтирован, но ${BLUE}ОСТАНОВЛЕН${NOCL}."
    echo "${PREF}${_user}::Запускаем контейнер и производим подключение к нему..."

    docker start "${container_id_exited}" &> /dev/null
	echo -e "${PREF}ЗАХОДИМ ВНУТРЬ КОНТЕЙНЕРА '${GREEN}${container_name}${NOCL}'"
    show_line

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
    echo -e "${PREF}${_user}::Контейнер '${container_name}' ${BLUE}НЕ СМОНТИРОВАН${NOCL}!"
    echo "${PREF}${_user}::Производим запуск и монтирование контейнера и подключаемся к нему..."

    user_group_id="${U_ID}:${G_ID}"
    [ -z "${script_to_run}" ] && [ "${run_with_root}" = yes ] && user_group_id="root:root";

    echo -e "${PREF}ЗАХОДИМ ВНУТРЬ КОНТЕЙНЕРА '${GREEN}${container_name}${NOCL}'"
    show_line

    container_id_exited=$(docker ps -aq --filter name="${container_name}" --filter status=exited )

    if [ -n "${container_id_exited}" ] ; then
    	#    Запускаем остановленный контейнер
        docker start "${container_name}" &> /dev/null
        docker_exec "${container_id_exited}" "${script_to_run}" "" "${arch}"
    else
#    	а если контейнера нет - то создаем его и запускаем
        docker_run "${script_to_run}" "${container_name}" "${arch}" "${user_group_id}"
    fi
}

#-------------------------------------------------------------------------------
# Собираем образ для запуска контейнера
#-------------------------------------------------------------------------------
build_image(){

    echo -e "${PREF}Запускаем сборку ${BLUE}НОВОГО${NOCL} образа ${IMAGE_NAME}"
    show_line

    context=$(dirname "$(pwd)")
    if docker build \
        --tag "${IMAGE_NAME}" \
        --build-arg UID="${U_ID}" \
        --build-arg GID="${G_ID}" \
        --build-arg USER="${USER}" \
        --build-arg GROUP="${GROUP}" \
        --build-arg APPS_ROOT="${APPS_ROOT}" \
        --build-arg APP_NAME="${APP_NAME}" \
        --build-arg TZ=Europe/Moscow \
        --file "${DOCKER_FILE}" \
        "${context}/" ; then

        show_line
        echo "${PREF}Docker-образ собран без ошибок."

    else
    	error="${PREF}В процессе сборки Docker-образа '${IMAGE_NAME}' возникли ошибки."
    	run_when_error "${IMAGE_NAME}" "${error}"
        exit 1
    fi
    show_line
}


#-------------------------------------------------------------------------------
# Удаляем готовый образ и собираем его заново для запуска контейнера
#-------------------------------------------------------------------------------
rebuild_image(){

    echo "${PREF}Удаляем предыдущий образ '${IMAGE_NAME}'"
    script_to_run=${1}

    container_id_exited=$(docker ps --filter ancestor="${IMAGE_NAME}" -q)
    if [ -n "${container_id_exited}" ] ; then
    	purge_containers "${container_id_exited}" &>/dev/null
    else
        container_id_exited=$(docker ps -a --filter ancestor="${IMAGE_NAME}" -q)
        [ -n "${container_id_exited}" ] && docker rm ${container_id_exited} &> /dev/null
    fi

    get_image_id && docker rmi -f "${IMAGE_NAME}"
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
                	echo "${PREF}Запускаем сборку пакета в контейнере '${container_name}' ..."
                	show_line
                	manager_container_to_make "${script_to_run}" "" "${arch}"
                }

            fi
        fi
    fi

}

#-------------------------------------------------------------------------------
# Отображаем меню с запросом об архитектуре сборки
#-------------------------------------------------------------------------------
ask_arch_to_run(){

	list_arch=${1}
	script_to_run=${2}
	count=0; choice=${3}
	extra_menu_pos="Все\tархитектуры"

	list_arch_menu=${list_arch};
	[ -n "${script_to_run}" ] && list_arch_menu="${list_arch} ${extra_menu_pos}"
	echo -e "Доступные ${BLUE}архитектуры${NOCL} для сборки [Q/q - выход]:"
	show_line

	for _arch_ in ${list_arch_menu} ; do
		count=$((count+1))
		echo -e " ${count}. ${BLUE}${_arch_}${NOCL}"
	done
	show_line
	read_choice "Выберите номер позиции из списка: " "${count}" choice
}


#-------------------------------------------------------------------------------
# Печатаем заголовок для очередной сборки архитектуры
#-------------------------------------------------------------------------------
print_header(){
	arch=$(echo "${1}" | tr "[:lower:]" "[:upper:]")

	echo ""
	echo ""
	echo ""
	echo -e "		СОБИРАЕМ ДЛЯ АРХИТЕКТУРЫ ${GREEN}${arch}${NOCL}"
	echo ""
	echo ""
	echo ""
	show_line
}

#-------------------------------------------------------------------------------
# Подключаемся к контейнеру для сборки приложения в нем
#-------------------------------------------------------------------------------
manager_container_to_make(){

	script_to_run="${1}"
	run_with_root="${2:-no}"
	arch_to_run=${3}
	count=0; choice=''
	extra_menu_pos="Все\tархитектуры"

    if is_mac_os_x ; then
        ps -x | grep 'Docker.app' | grep -vq grep || {
            echo -e "${PREF}${RED}Сервис Docker не запущен! Для запуска наберите команду 'open -a Docker'${NOCL}"
            show_line
            exit 1
        }
    fi
#    если язык разработки Shell
    if [ "${DEVELOP_EXT}" = bash ] ; then
    	print_header "BASH"
		show_line
        container_run_to_make "${script_to_run}" "${run_with_root}" "$(get_container_name "all")" "all"
    else
#		если язык разработки Си или С++
    	list_arch="$(get_arch_list)"
#    	если указанная архитектура присутствует в списке
		list_size=$(echo "${list_arch}" | grep -cE '^[a-zA-Z]' | tr "[:upper:]" "[:lower:]")
		if [ -z "${arch_to_run}" ]; then
#        	если не задана архитектура сборки - запрашиваем ее
			ask_arch_to_run "${list_arch}" "${script_to_run}" choice
		else
			if [ "${arch_to_run}" = all ]; then
#        		если архитектура - all
				choice=$(( list_size + 1))
			else
#        		если указана в аргументах конкретная архитектура
				choice=$(echo "${list_arch}" | grep -n "${arch_to_run}" | head -1 | cut -d':' -f1)
				if [ -z "${choice}" ] ; then
					echo -e "${PREF}${RED}Не верно указана архитектура для сборки!${NOCL}"
					show_line
					ask_arch_to_run "${list_arch}" "${script_to_run}" choice
				fi
			fi
		fi

		if [ "${choice}" = q ] ; then exit 1;
		else

			if [ "${choice}" -gt "${list_size}" ] && [ -n "${script_to_run}" ]; then
				num=1;
	#       	в случае если выбран крайний пункт в списке и это пункт "Все\tархитектуры", то..
#	set -x
				for _arch in ${list_arch}; do
#					[ "${num}" = 1 ] && show_line
					[ "${num}" -le "${list_size}" ] && print_header "${_arch}"
#					[ "${num}" -lt "${list_size}" ] && show_line
					container_run_to_make "${script_to_run}" "${run_with_root}" "${_arch}"

#
					num=$((num + 1))
				done
#	set	+x
			else
				arch=$(echo "${list_arch}" | tr '\n' ' ' | tr -s ' ' | cut -d' ' -f"${choice}")
				print_header "${arch}"
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
            echo -e "${PREF}${RED}Данные о версии пакета введены некорректно!${NOCL}"
        else
            if echo "${ver_to_set}" | grep -q '-' ; then
                ver_stage="$(echo "${ver_to_set}" | cut -d '-' -f2 | tr -d '0-9') "
                if [ -z "${ver_stage}" ]; then pos=2; else pos=3; fi
                ver_release=$(echo "${ver_to_set}" | cut -d '-' -f"${pos}")
                if [ -z "${ver_release}" ]; then ver_stage=${ver_stage// /}; fi
            else
                ver_stage=''; ver_release=''
            fi
            [ -z "${ver_stage}" ] && ver_main=${ver_main// /}
            set_version_part "PACKAGE_VERSION"  "${ver_main}"
            set_version_part "PACKAGE_STAGE"    "${ver_stage}"
            set_version_part "PACKAGE_RELEASE"  "${ver_release}"
            full_ver=$(echo "${ver_main}${ver_stage}${ver_release}" | sed -e 's/[[:space:]]*$//' | tr ' ' '-')
            echo "${PREF}Версия пакета '${full_ver}' успешно установлена!"
        fi
    else
        ver_main="$(get_version_part     "PACKAGE_VERSION")"
        ver_stage="$(get_version_part    "PACKAGE_STAGE")"
        ver_release="$(get_version_part  "PACKAGE_RELEASE")"
        full_ver=$(echo "${ver_main}${ver_stage}${ver_release}" | sed -e 's/[[:space:]]*$//' | tr ' ' '-')
        echo "${PREF}Текущая версия пакета '${full_ver}'"
    fi
    show_line
}


#-------------------------------------------------------------------------------
# Удаляем контейнер с заданной в аргументе архитектурой
#-------------------------------------------------------------------------------
remove_arch_container(){
	arch_build=${1}
	if [ "${arch_build}" ]; then
	    if get_arch_list | grep -q "${arch_build}" ; then
	        container_id=$(get_container_id "${APP_NAME}-${arch_build}*")
	        if [ "${container_id}" ]; then
	            purge_containers "${container_id}" &>/dev/null
	        	echo -e "${PREF}Контейнер c архитектурой сборки ${GREEN}${arch_build}${NOCL} успешно удален."
	        else
	            echo -e "${PREF}Контейнер c архитектурой сборки ${GREEN}${arch_build}${NOCL} не существует."
	        fi


	    else
	        echo -e "${PREF}Указанная архитектура сборки ${RED}отсутствует.${NOCL}"
	    fi

	else
		echo -e "${PREF}${RED}Не задана${NOCL} архитектура сборки для удаления!"
	fi
	show_line

}

#-------------------------------------------------------------------------------
# Проверяем был ли в аргументах передан флаг отладки
#-------------------------------------------------------------------------------
set_debug_status(){
    if [[ "${*}" =~ -vb|debug|-v ]] ; then debug=YES; else debug=NO; fi
    sedi "s|DEBUG=.*$|DEBUG=${debug}|" ./package.app
    echo "${*}" | sed "s/debug//g; s/-vb//g; s/-v//g;" | tr -d ' '
}

#-------------------------------------------------------------------------------
# Удаляем готовый образ и собираем его заново для запуска контейнера
#-------------------------------------------------------------------------------
show_help(){
    show_line
    echo -e "${BLUE}Котомка [kotomka] - скрипт предназначенный для быстрого развертывания среды разработки Entware"
    echo -e "в Docker-контейнере для роутеров Keenetic с целью сборки пакетов на языках семейства Bash, С, С++.${NOCL}"
    show_line
    echo -e "${BLUE}Допустимые аргументы:${NOCL}"
    show_line
    echo "build    [-bl] - сборка образа на основании которого будут собираться контейнеры с указанными архитектурами."
    echo "make     [-mk] - сборка пакета и копирование его на роутер"
    echo "make <arch>    - сборка пакета и копирование его на роутер для указанной/ых архитектур,"
    echo "                 где arch может принимать следующие значения: ."
    echo "                 all - для всех типов архитектур в файле конфигурации '${DEV_CONFIG_NAME}'."
    echo "                 aarch64 - для ARCH64 архитектуры, "
    echo "                 mips - для MIPS архитектуры "
    echo "                 mipsel - для MIPSEL архитектуры"
    echo " 				   armv5  - для ARMv5 архитектуры"
    echo " 				   armv7-2.6 - для ARMv7 версии 2.6 архитектуры"
	echo " 				   armv7-3.2 - для ARMv7 версии 3.2 архитектуры"
    echo " 				   x64  - для X64 архитектуры"
    echo " 				   x86  - для X86 архитектуры"
    echo "make ver       - отображаем текущую версию собираемого пакета"
    echo "make ver <N>   - устанавливаем версию собираемого пакета, где номер в формате <N-stage-rel>"
    echo "                 N - номер версии, например 1.0.12"
    echo "                 stage - стадия разработки [alpha, betta, preview]"
    echo "                 rel - выпускаемый номер релиза, например 01"

    echo "rebuild  [-rb] - Удаляем готовый образ и собираем его заново с последующим запуском сборки пакета"
    echo "copy     [-cp] - копирование уже собранного пакета на роутер"
    echo "term     [-tr] - подключение к контейнеру без исполнения скриптов под пользователем '${USER}'."
	echo "term <arch>    - подключение к контейнеру под пользователем '${USER}' для указанной/ых архитектур,"
	echo "                 параметр arch, такой же, как и в команде make (см. выше)."
    echo "root     [-rt] - подключение к контейнеру без исполнения скриптов под пользователем 'root'"
	echo "root <arch>    - подключение к контейнеру под пользователем 'root' для указанной/ых архитектур,"
	echo "                 параметр arch, такой же, как и в команде make (см. выше)."
    echo "debug    [-vb] - дополнительный флаг к предыдущим аргументам для запуска в режиме отладки"
    echo "test     [-ts] - запуск тестов на удаленном устройстве. "
    echo "reset    [-rs] - cбрасываем в первоначальное состояние пакет до установки языка разработки."
    echo "help     [-hl] - отображает настоящую справку"

    show_line "-"
    echo -e "Примеры запуска:"
    show_line "-"
    echo  " ./build.run make mips  - запускаем сборку пакета для платформы mips."
    echo  " ./build.run build all  - запускаем сборку среды разработки и первоначальную сборку пакета."
    echo  " 						 для всех заданных архитектур в файле конфигурации ./build.conf"
    echo  " ./build.run -mk -vb    - запускаем сборку пакета с опцией отладки."
    echo  " ./build.run -cp        - копируем уже ранее собранный пакет на удаленное устройство (роутер)."
    echo  " ./build.run term       - заходим в ранее собранный контейнер под именем разработчика."
    show_line
}

show_line
prepare_code_structure

args="$(set_debug_status "${*}")"

#   Сбрасываем в первоначальное состояние пакет до установки языка разработки
if [[ "${args}" =~ reset|-rs ]] ; then
    reset_data;
    exit 0;
else
    [[ "${args}" =~ rebuild|-rb ]] && reset_data
    check_dev_language
fi

arg_1=$(echo "${1}" | cut -d' ' -f1)
arg_2=$(echo "${1}" | cut -d' ' -f2)

case "${arg_1}" in
	term|-tr ) 	[ -n "${arg_2}" ] && manager_container_to_make "" "" "${arg_2}" ;;
	root|-rt) 	[ -n "${arg_2}" ] && manager_container_to_make "" "yes" "${arg_2}" ;;
	build|-bl) 				  build_image ;;
	make|-mk)
	    case  "${arg_2}" in
	        ver* )          package_version_set "$(echo "${arg_2//ver/}" | sed -e 's/^[[:space:]]*//')" ;;
	        *    )          manager_container_to_make "${SCRIPT_TO_MAKE}" "" "${arg_2}" ;;
	    esac
	    ;;
	copy|-cp )  	        manager_container_to_make "${SCRIPT_TO_COPY}" ;;
    test|-ts )  	        manager_container_to_make "${SCRIPT_TO_TEST}" ;;
    rebuild|-rb)            rebuild_image "${SCRIPT_TO_MAKE}" ;;
	remove|rm|del| -rm)			remove_arch_container "${arg_2}";;
    help|-h|--help)         show_help ;;
	*)
							echo -e "${RED}${PREF}Аргументы запуска скрипта не заданы, либо не верны!${NOCL}";
                            show_help
    ;;
esac
