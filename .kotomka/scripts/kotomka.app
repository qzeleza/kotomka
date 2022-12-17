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
DEV_CONFIG_FILE="../../${DEV_CONFIG_NAME}"


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
DEVELOP_EXT=$(echo "${APPS_LANGUAGE}" | tr "[:upper:]" "[:lower:]")

#-------------------------------------------------------------------------------
#	Пути к файлам внутри контейнера
#-------------------------------------------------------------------------------
SCRIPTS_PATH=${APPS_ROOT}/${APP_NAME}/${DEV_NAME_PATH}/apps
SCRIPT_TO_MAKE=${SCRIPTS_PATH}/package.app
SCRIPT_TO_COPY=${SCRIPTS_PATH}/copy.app
SCRIPT_TO_TEST=${SCRIPTS_PATH}/testsrun.app
WORK_PATH_IN_CONTAINER="${APPS_ROOT}/${APP_NAME}/${DEV_NAME_PATH}"

#-------------------------------------------------------------------------------
#  Формируем имя контейнера в зависимости от архитектуры процессора.
#-------------------------------------------------------------------------------
get_container_name()(echo "${APP_NAME}-${1}")


#-------------------------------------------------------------------------------
#  Получаем id контейнера по его имени.
#-------------------------------------------------------------------------------
get_image_id()(docker image ls -q "${IMAGE_NAME}")

#-------------------------------------------------------------------------------
#  Сбрасываем в первоначальное состояние пакет до установки языка разработки.
#-------------------------------------------------------------------------------
reset_data(){
    rm -rf "${PATH_PREFIX}.${DEV_ROOT_PATH}/${DEV_SRC_PATH}/*" "${PATH_PREFIX}.${DEV_ROOT_PATH}/${DEV_COMPILE_NAME}/*"
    echo -e "${RED}${PREF}Пакет сброшен в первоначальное состояние, до установки языка разработки.${NOCL}"
    show_line
}


#-------------------------------------------------------------------------------
#  Получаем список архитектур для которых ведется разработка.
#  в соответствии с правилами указанными в DEV_CONFIG_FILE
#-------------------------------------------------------------------------------
arch_list(){

    cat < "${DEV_CONFIG_FILE}" \
        | grep -v '#' |grep -E "ARCH_.*_ROUTER" \
        | grep -v 'NO' | sed 's/ARCH_\(.*\)_ROUTER_IP.*/\1/' \
        | tr "[:upper:]" "[:lower:]" | sed 's/[_]/-/1; s/_/./1'

}


#-------------------------------------------------------------------------------
#  Создаем файл манифеста для заданного типа языка разработки
#-------------------------------------------------------------------------------
prepare_makefile(){
set -x
    if [ -n "${1}" ] ; then arch="${1}/"; else arch=""; fi

    app_router_dir=$(escape "/opt${APPS_ROOT}/${APP_NAME}")
    github_url=$(escape "https://github.com/${GITHUB_ACCOUNT_NAME}/${APP_NAME}")
    source_dir=$(escape "${APPS_ROOT}/${APP_NAME}")

    make_file="${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_COMPILE_NAME}/${arch}Makefile"

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
         s/@SOURCE_DIR/${source_dir}/g;" "${make_file}"

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

    if [ -n "${1}" ] ; then arch="${1}/"; else arch=""; fi

    case "${APPS_LANGUAGE}" in
        CCC|ccc)    lang="Си" ;;
        CPP|cpp)    lang="С++";;
        BASH|bash)  lang="Bash";;
    esac

    echo -e "${BLUE}${PREF}Заявленным языком разработки является '${lang}'${NOCL}"
    echo -e "${BLUE}${PREF}Производим замену файлов в соответствии с установками в ${DEV_CONFIG_NAME} ${NOCL}"
    show_line

    mainfile_path="${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_SRC_PATH}"
    makefile="${mainfile_path}/Makefile"
    mainfiles="${mainfile_path}/main.*"
    rm -f "${makefile}" "${mainfiles}"

    if [ "${DEVELOP_EXT}" = ccc ] ; then ext=${DEVELOP_EXT:0:1}; else ext=${DEVELOP_EXT}; fi

    case ${DEVELOP_EXT} in
        cpp|CPP|ccc|CCC)
            cp -f "../templates/code/make/Makefile.${DEVELOP_EXT}"      "${makefile}"
            sedi  "s|@APP_NAME|${APP_NAME}|g"                           "${makefile}"
            ext_file=$(echo "${mainfiles}" | sed "s|main\.\*$|main.${ext}|")
            cp -f "../templates/code/src/main.${DEVELOP_EXT}"           "${ext_file}"
            ;;

        BASH|bash)
            cp "../templates/code/src/main.sh"                      "${mainfile_path}/${APP_NAME}"
            ;;
        *)
            show_line
            echo -e "${RED}${PREF}Не распознан язык разработки в файле ${DEV_CONFIG_FILE}${NOCL}"
            echo -e "${BLUE}${PREF}Текущее значение APPS_LANGUAGE = ${APPS_LANGUAGE}.${NOCL}"
            echo -e "${BLUE}${PREF}Задайте одно из значений: CCC (Си), CPP (C++) или BASH.${NOCL}"
            show_line
            exit 1
            ;;
    esac

    manifest_scripts_path="${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_COMPILE_NAME}/${DEV_MANIFEST_DIR_NAME}"
#   создаем скрипты для сборки файла манифеста
    mkdir_when_not "${manifest_scripts_path}"
    makefile_path="${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_COMPILE_NAME}/${arch}"


#   и копируем сам файл манифеста
    makefile_path="${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_COMPILE_NAME}/${arch}"
    mkdir_when_not "${makefile_path}"
    cp -f "../templates/compile/Manifest.${DEVELOP_EXT}"     "${makefile_path}Makefile"

    #   создаем секции манифеста и файлы для них
    create_sections "${manifest_scripts_path}"
    sedi '/^[[:space:]]*$/d' "${makefile_path}Makefile"

	prepare_makefile "${arch}"

#   меняем имя пакета в файле для удаленных тестов
    tests_path="${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_TESTS_NAME}"
    cp -rf "../templates/tests/" "${tests_path}"
    sedi "s|@APP_NAME|${APP_NAME}|g"                    "${tests_path}/modules/hello.bats"
}


#-------------------------------------------------------------------------------
#  Проверяем соответствия флага языка разработки и текущий манифест для сборки пакета
#-------------------------------------------------------------------------------
check_dev_language(){
set -x
    if [ -n "${1}" ] ; then arch="${1}/"; else arch=""; fi

    manifest_file=$(find ../.. -type f | grep "${DEV_COMPILE_NAME}/${arch}Makefile" | head -1)

    if [ -n "${manifest_file}" ]; then
        if ! cat < "${manifest_file}" | grep -qi "для ${DEVELOP_EXT}"; then
            echo -e "${RED}${PREF}Обнаружено несоответствие файлов проекта с заявленным${NOCL}"
            echo -e "${RED}${PREF}языком разработки для архитектуры процессора ${BLUE}${PREF}${arch}${NOCL}"
            set_dev_language "${arch}"
        fi
    else
        set_dev_language "${arch}"
    fi
}

#-------------------------------------------------------------------------------
#  Создаем структуру папок для разработки в случае
#  инициализации проекта (описана в dev.conf) передаем
#  внутрь, как минимум одно и как максимум несколько названий
#  архитектуры процессоров разделенных пробелами
#-------------------------------------------------------------------------------
prepare_code_structure(){
set -x
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
    [ -n "${DEV_IPK_NAME}" ] && ! [ -d "${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_IPK_NAME}" ] || {
        mkdir -p "${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_IPK_NAME}"
    }

# блок необходим в случае, если необходимо создавать
# разные файлы манифеста для каждой архитектуры устройства
#    list_arch=$(arch_list)
#    for arch in ${list_arch}; do
#        [ -d "${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_COMPILE_NAME}/${arch}" ] || {
#            mkdir -p "${DEV_ROOT_PATH}/${DEV_COMPILE_NAME}/${arch}/${DEV_MANIFEST_DIR_NAME}"
#            check_dev_language "${arch}"
#            prepare_makefile "${arch}"
#        }
#    done
    [ -d "${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_COMPILE_NAME}/" ] || {
        mkdir -p "${PATH_PREFIX}${DEV_ROOT_PATH}/${DEV_COMPILE_NAME}/${DEV_MANIFEST_DIR_NAME}"
        check_dev_language "${arch}"
    }
set +x
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
#   Если система Linux
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
purge_running_container(){
	container_id_exited="${1}"
	docker stop "${container_id_exited}"
	docker rm "${container_id_exited}"
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
    arch_build=${4}

    router_ip=$(cat < "${DEV_CONFIG_FILE}" \
                | grep -v '#' | grep -v 'NO' | grep -E "ARCH_.*_ROUTER" \
                | grep -i "${arch_build//-/_}" \
                | cut -d'=' -f2)
    router_port=$(cat < "${DEV_CONFIG_FILE}" \
                    | grep -v '#' | grep -v 'NO' | grep -E "ARCH_.*_PORT" \
                    | grep -i "${arch_build//-/_}" \
                    | cut -d'=' -f2)

    if [ "${root}" = root ]; then user="--user root:root"; else user="--user ${USER}:${GROUP}"; fi
    docker exec \
			--interactive --tty \
			--workdir "${WORK_PATH_IN_CONTAINER}" \
			--env ROUTER_IP="${router_ip}" --env PORT="${router_port}" \
			--env COMPILE_NAME="${DEV_COMPILE_NAME}" \
			--env ROOT_PATH="${DEV_ROOT_PATH}" \
			--env ARCH_BUILD="${arch_build}" ${user} \
			"${container_id_exited}" /bin/bash ${script_to_run}
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
    arch=${3}
    user=${4}
    context=$(dirname "$(dirname "$(pwd)")")

    if [ -n "${container_name}" ] ; then name_cnt="--name ${container_name}"; else name_cnt=""; fi

    docker run \
           --interactive --tty \
           --workdir "${WORK_PATH_IN_CONTAINER}" \
           --env ROUTER_IP="${router_ip}" -e PORT="${router_port}" \
           --env ARCH_BUILD="${arch}" \
           --env COMPILE_NAME="${DEV_COMPILE_NAME}" \
           --env ROOT_PATH="${DEV_ROOT_PATH}" \
           --user "${user}" \
           ${name_cnt} \
           --mount type=bind,src="${context}",dst="${APPS_ROOT}"/"${APP_NAME}" \
           "$(get_image_id)" /bin/bash ${script_to_run} || {
               show_line;
               echo "${PREF}В процессе сборки пакета возникли ошибки в контейнере ${container_name} !"
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

   	echo "${_user}::Контейнер разработки '${container_name}' запущен."
    echo "${_user}::Производим подключение к контейнеру..."

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
    echo "${_user}::Контейнер разработки '${container_name}' смонтирован, но остановлен."
    echo -n "${_user}::Запускаем контейнер и производим подключение к нему..."
    docker start "${container_id_exited}"
    show_line

    docker_exec "${container_id_exited}" "${script_to_run}" "${_user}" "${arch}" || {
    	docker rm "${container_id_exited}"
    	connect_when_not_mounted "${script_to_run}" "${run_with_root}" "${arch}" "${container_name}"
    }
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
    echo "${_user}::Контейнер '${container_name}' не смонтирован!"
    echo "${_user}::Производим запуск и монтирование контейнера и подключаемся к нему..."

    user_group_id="${U_ID}:${G_ID}"
    [ -z "${script_to_run}" ] && [ "${run_with_root}" = yes ] && user_group_id="root:root";

    echo "${PREF}ЗАХОДИМ ВНУТРЬ КОНТЕЙНЕРА '${container_name}'"
    #	Если контейнер запущен или просто собран - удаляем его (так, как там могут быть ошибки)
    container_id_exited=$(docker ps -aq --filter ancestor="${IMAGE_NAME}" --filter status=exited )
    if [ -n "${container_id_exited}" ] ; then
        docker start "${container_name}" &> /dev/null
        docker_exec "${container_id_exited}" "${script_to_run}" "" "${arch}"
    else
        docker_run "${script_to_run}" "${container_name}" "${arch}" "${user_group_id}"
    fi
}

#-------------------------------------------------------------------------------
# Собираем образ для запуска контейнера
#-------------------------------------------------------------------------------
build_image(){

    echo "${PREF}Запускаем сборку НОВОГО образа ${IMAGE_NAME}"
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
        --file "${DOCKER_FILE}" \
        "${context}/" ; then

        show_line
        echo "${PREF}Docker-образ собран без ошибок."

    else
        show_line;
        echo "${PREF}В процессе сборки Docker-образа возникли ошибки!"
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
        docker stop "${container_id_exited}" &>/dev/null
        docker rm "${container_id_exited}"   &>/dev/null
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
        connect_when_run "${script_to_run}" "${run_with_root}" "${container_id_up}"  "${arch}" "${container_name}"
    else
        container_id_down=$(docker ps -qa  --filter name="${container_name}" --filter status=exited)
        if [ -n "${container_id_down}" ]; then
            connect_when_stopped "${script_to_run}" "${run_with_root}" "${container_id_down}" "${arch}" "${container_name}"
        else
            if get_image_id; then
                connect_when_not_mounted "${script_to_run}" "${run_with_root}" "${arch}" "${container_name}"
            else
                build_image && {
                	echo "${PREF}Запускаем сборку пакета в контейнере '${container_name}' ..."
        			docker_run "${script_to_run}" "${container_name}" "${arch}" "${U_ID}:${G_ID}"
                }

            fi
        fi
    fi

}

#-------------------------------------------------------------------------------
# Подключаемся к контейнеру для сборки приложения в нем
#-------------------------------------------------------------------------------
manager_container_to_make(){
set -x
	script_to_run="${1}"
	run_with_root="${2:-no}"
	all_arch_run=${3}
	count=0; choice=''
	extra_menu_pos="Все\tархитектуры"

    if is_mac_os_x ; then
        ps -x | grep 'Docker.app' | grep -vq grep || {
            echo -e "${PREF}${RED}Сервис Docker не запущен! Для запуска наберите команду 'open -a Docker'${NOCL}"
            show_line
            exit 1
        }
    fi
    if [[ "${APPS_LANGUAGE}" =~ BASH|bash|Bash|sh|SH|Sh ]] ; then
        container_run_to_make "${script_to_run}" "${run_with_root}" "$(get_container_name "all")" "all"
        show_line
    else

    	list_arch="$(arch_list)"
        list_arch_menu=${list_arch}; [ -n "${script_to_run}" ] && list_arch_menu="${list_arch} ${extra_menu_pos}"

        if [ -z "${all_arch_run}" ]; then
            echo -e "Доступные ${BLUE}архитектуры${NOCL} для сборки:"
            show_line

            for _arch_ in ${list_arch_menu} ; do
                count=$((count+1))
                echo -e " ${count}. ${BLUE}${_arch_}${NOCL}"
            done
            show_line
            read_choice "Выберите номер позиции из списка: " "${count}" choice
        else
            choice=${count}
        fi
        show_line

        if [ "${choice}" = q ] ; then exit 1;
        elif [ "${choice}" = ${count} ] && [ -n "${script_to_run}" ]; then
#       в случае если выбран крайний пункт в списке и это пункт "Все\tархитектуры", то..
            for _arch in ${list_arch}; do
                container_run_to_make "${script_to_run}" "${run_with_root}" "${_arch}"
                docker stop "$(get_container_name "${_arch}")"
                show_line
            done
        elif [ -z "${script_to_run}" ]; then
#       если запустили просто в режиме терминала
            arch=$(echo "${list_arch}" | tr '\n' ' ' | tr -s ' ' | cut -d' ' -f"${choice}")
            container_run_to_make "${script_to_run}" "${run_with_root}" "${arch}"
            docker stop "$(get_container_name "${arch}")"
            show_line
        else
            echo "${PREF}${RED}Ошибка в переданных аргументах ${NOCL}"
            echo "${PREF}Запуск в режиме 'make', но не был сделан выбор из списка."
        fi
    fi
set +x
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
    echo "build    [-bl] - сборка образа и последующий запуск сборки пакета"
    echo "make     [-mk] - сборка пакета и копирование его на роутер"
    echo "make all       - сборка пакета и копирование его на роутер для всех указанных архитектур"
    echo "                 в файле конфигурации '${DEV_CONFIG_NAME}'."
    echo "make ver       - отображаем текущую версию собираемого пакета"
    echo "make ver <N-stage-rel> - устанавливаем версию собираемого пакета, где"
    echo "                         N - номер версии, например 1.0.12"
    echo "                         stage - стадия разработки [alpha, betta, preview]"
    echo "                         rel - выпускаемый номер релиза, например 01"

    echo "rebuild  [-rb] - Удаляем готовый образ и собираем его заново с последующим запуском сборки пакета"
    echo "copy     [-cp] - копирование уже собранного пакета на роутер"
    echo "term     [-tr] - подключение к контейнеру без исполнения скриптов под пользователем '${USER}'."
    echo "root     [-rt] - подключение к контейнеру без исполнения скриптов под пользователем 'root'"
    echo "debug    [-vb] - дополнительный флаг к предыдущим аргументам для запуска в режиме отладки"
    echo "test     [-ts] - запуск тестов на удаленном устройстве. "
    echo "init     [-in] - cбрасываем в первоначальное состояние пакет до установки языка разработки."
    echo "help     [-hl] - отображает настоящую справку"

    show_line "-"
    echo -e "Примеры запуска:"
    show_line "-"
    echo  " ./kotomka build      - запускаем сборку среды разработки и первоначальную сборку пакета."
    echo  " ./kotomka -mk -vb    - запускаем сборку пакета с опцией отладки."
    echo  " ./kotomka -cp        - копируем уже ранее собранный пакет на удаленное устройство (роутер)."
    echo  " ./kotomka term       - заходим в ранее собранный контейнер под именем разработчика."
    show_line
}

show_line
prepare_code_structure

args="$(set_debug_status "${*}")"

#   Сбрасываем в первоначальное состояние пакет до установки языка разработки
if [[ "${args}" =~ init|-in ]] ; then
    reset_data;
    exit 0;
else
    [[ "${args}" =~ rebuild|-rb ]] && reset_data
    check_dev_language
fi
case "${1}" in
	term|-tr )   	        manager_container_to_make "" ;;
	root|-rt) 		        manager_container_to_make "" "yes" ;;
	make*|-mk*|build*|-bl*)
	    mk_arg=$(echo "${1}" | cut -d' ' -f2-)
	    case  "${mk_arg}" in
	        ver* )          package_version_set "$(echo "${mk_arg//ver/}" | sed -e 's/^[[:space:]]*//')" ;;
	        all  )          manager_container_to_make "${SCRIPT_TO_MAKE}" "" "all" ;;
	        *    )          manager_container_to_make "${SCRIPT_TO_MAKE}" ""  ;;
	    esac
	    ;;
	copy|-cp )  	        manager_container_to_make "${SCRIPT_TO_COPY}" ;;
    test|-ts )  	        manager_container_to_make "${SCRIPT_TO_TEST}" ;;
    rebuild|-rb)            rebuild_image "${SCRIPT_TO_MAKE}" ;;
    help|-h|--help)         show_help ;;
	*)                      echo -e "${RED}${PREF}Аргументы запуска скрипта не заданы, либо не верны!${NOCL}"
                            show_help ;;
esac

