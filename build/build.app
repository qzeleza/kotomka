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
is_mac_os_x()(uname -a | grep -q Darwin)
awkfun()(is_mac_os_x && gawk "$@" || awk "$@")
sedi()(is_mac_os_x && sed -i '' "$@" || sed -i "$@")
escape()(echo "${1}" | sed 's|\/|\\/|g')

#-------------------------------------------------------------------------------
# Печатаем строку из 100  знаков равно
#-------------------------------------------------------------------------------
show_line(){
    if [ -z "${1}" ] ; then div='=' ; else div=${1} ; fi
    printf "%100s\n" ' ' | tr " " "${div}"
}


[[ "$(pwd)" =~ '/build' ]] || {
    show_line
    echo -e "${RED}${PREF}Запуск скрипа возможен только из папки проекта ./build${NOCL}."
    show_line
    exit 1
}

. ./CONFIG
. ./scripts/library

#-------------------------------------------------------------------------------
# Получаем необходимую информацию о версии пакета
#-------------------------------------------------------------------------------
get_version_part(){
	part=${1}
	cat < "$(pwd)/CONFIG" | grep "${part}" | cut -d'=' -f2
}
#-------------------------------------------------------------------------------
# Устанавливаем информацию о версии пакета
#-------------------------------------------------------------------------------
set_version_part(){
	part=${1}
	value=${2}
	sedi "s|\(${part}=\).*|\1${value}|" "$(pwd)/CONFIG"
}


#-------------------------------------------------------------------------------
VERSION=$(get_version_part VERSION)
STAGE=$(get_version_part STAGE)
RELEASE=$(get_version_part RELEASE)
#-------------------------------------------------------------------------------
if [ -n "${STAGE}" ]; then
    FULL_VERSION="${VERSION} ${STAGE} ${RELEASE}";
else
    FULL_VERSION="${VERSION} ${RELEASE}";
fi
#-------------------------------------------------------------------------------

DEBUG=YES # флаг отладки процесса сборки образа
#-------------------------------------------------------------------------------
APP_NAME=$(pwd | sed "s/.*\\${APPS_ROOT}\/\(.*\).*$/\1/;" | cut -d'/' -f1)
IMAGE_NAME=$(echo "${DOCKER_ACCOUNT_NAME}" | tr "[:upper:]" "[:lower:]")/${APP_NAME}-dev

#-------------------------------------------------------------------------------
#	Пути к файлам на машине разработчика
#-------------------------------------------------------------------------------
DOCKER_FILES_PATH=$(pwd)/docker
DOCKER_FILE=${DOCKER_FILES_PATH}/Dockerfile
DEVELOP_EXT=$(echo "${APPS_LANGUAGE}" | tr "[:upper:]" "[:lower:]")

#-------------------------------------------------------------------------------
#	Пути к файлам внутри контейнера
#-------------------------------------------------------------------------------
SCRIPTS_PATH=${APPS_ROOT}/${APP_NAME}/build/scripts
SCRIPT_TO_MAKE=${SCRIPTS_PATH}/package.app
SCRIPT_TO_COPY=${SCRIPTS_PATH}/copy.app
SCRIPT_TO_TEST=${SCRIPTS_PATH}/runtests.app

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
    rm -rf ../code/* ../compile/*
    echo -e "${RED}${PREF}Пакет сброшен в первоначальное состояние, до установки языка разработки.${NOCL}"
    show_line
}


arch_list(){
    echo "aarch64-3.10 \
          mips-3.4 \
          mipsel-3.4"

#    echo "aarch64-3.10 \
#          armv5-3.2 \
#          armv7-2.6 \
#          armv7-3.2 \
#          mips-3.4 \
#          mipsel-3.4 \
#          x64-3.2 \
#          x86-2.6"
}

#-------------------------------------------------------------------------------
#  Запускаем Docker exec с параметрами
#   $1 - docker_id
#   $2 - скрипт для запуска внутри контейнера сразу после входа в него
#   $3 - root, если пусто, то входим под именем текущего пользователя
#   $4 - архитектура процессора
#-------------------------------------------------------------------------------
docker_exec(){
    docker_id=${1}; script_to_run=${2}; root=${3}; arch_build=${3}
    if [ -n "${root}" ]; then user="--user root:root"; else user="--user ${USER}:${GROUP}"; fi
    docker exec -w "${APPS_ROOT}/${APP_NAME}/build" \
                -e ARCH_BUILD="${arch_build}" ${user} \
                -it "${docker_id}" /bin/bash ${script_to_run}
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
    context=$(dirname "$(pwd)")

    if docker run \
           --interactive \
           --tty \
           --workdir "${APPS_ROOT}/${APP_NAME}/build" \
           --env ARCH_BUILD="${arch}" \
           --user "${user}" \
           --name "${container_name}" \
           --mount type=bind,src="${context}",dst="${APPS_ROOT}"/"${APP_NAME}" \
           "$(get_image_id)" /bin/bash ${script_to_run} ;  then

        version_txt="v$(echo "${FULL_VERSION} "| tr -s ' ' '-')"
#        docker commit "${container_name}" "${IMAGE_NAME}:${version_txt}"
    else
        show_line;
#        echo "${PREF}В процессе сборки пакета возникли ошибки!"
        container_id="$(get_container_id "${container_name}")"
        docker rm "${container_id}" &>/dev/null
        echo "${PREF}Контейнер '${container_name}' удален!"
        exit 1

    fi
}
#-------------------------------------------------------------------------------
#  Создаем файл манифеста для заданного типа языка разработки
#-------------------------------------------------------------------------------
prepare_makefile(){

    extension=${1}

    app_router_dir=$(escape "/opt${APPS_ROOT}/${APP_NAME}")
    github_url=$(escape "https://github.com/${GITHUB_ACCOUNT_NAME}/${APP_NAME}")
    source_dir=$(escape "${APPS_ROOT}/${APP_NAME}")

    make_file="../compile/Makefile.${extension}"

    sed -i "${SEP}" "s/@APP_NAME/$(escape "${APP_NAME}")/g; \
         s/@VERSION/$(escape "${VERSION}" | tr -d ' ')/g; \
         s/@STAGE/$(escape "${STAGE}" | tr -d ' ')/g; \
         s/@APP_ROUTER_DIR/${app_router_dir}/g; \
         s/@RELEASE/$(escape "${RELEASE}")/g; \
         s/@LICENCE/$(escape "${LICENCE}")/g; \
         s/@AUTHOR/$(escape "${AUTHOR_NAME}")/g; \
         s/@EMAIL/$(escape "${AUTHOR_EMAIL}")/g; \
         s/@GITHUB/${github_url}/g; \
         s/@CATEGORY/$(escape "${APP_CATEGORY}")/g; \
         s/@SUBMENU/$(escape "${APP_SUBMENU}")/g; \
         s/@TITLE/$(escape "${APP_TITLE}")/g; \
         s/@SOURCE_DIR/${source_dir}/g;" "${make_file}"

    awkfun -i inplace -v r="${APP_DESCRIPTION}" '{gsub(/@DESCRIPTION/,r)}1' "${make_file}"

#    echo "${PREF}Makefile успешно создан"
}

#-------------------------------------------------------------------------------
#  Производим первоначальные настройки пакета в зависимости от заявленного языка разработки
#-------------------------------------------------------------------------------
set_dev_language(){

    case "${APPS_LANGUAGE}" in
        C|c)        lang="Си" ;;
        CPP|cpp)    lang="С++";;
        BASH|bash)  lang="Bash";;
    esac

    echo -e "${BLUE}${PREF}Заявленным языком разработки является '${lang}'${NOCL}"
    echo -e "${BLUE}${PREF}Производим замену файлов в соответствии с установками в ./build/CONFIG ${NOCL}"
    show_line

    rm -f ../code/Makefile.* ../code/main.* ../compile/Makefile* ../code/"${APP_NAME}"

    case ${DEVELOP_EXT} in
        cpp|CPP|c|C)
            cp -f "./.templates/make/Makefile.${DEVELOP_EXT}"   "../code/Makefile"
            sedi  "s|@APP_NAME|${APP_NAME}|g"                   "../code/Makefile"
            cp -f "./.templates/code/main.${DEVELOP_EXT}"       "../code/main.${DEVELOP_EXT}"
            ;;
        BASH|bash)
            cp "./.templates/code/main.sh"                      "../code/${APP_NAME}"
            ;;
        *)
            show_line
            echo -e "${RED}${PREF}Не распознан язык разработки в файле ./build/CONFIG${NOCL}"
            echo -e "${BLUE}${PREF}Текущее значение APPS_LANGUAGE = ${APPS_LANGUAGE}.${NOCL}"
            echo -e "${BLUE}${PREF}Задайте одно из значений: C, CPP или BASH.${NOCL}"
            show_line
            exit 1
            ;;
    esac
    cp -f "./.templates/compile/postinst"                    "../compile/postinst"
    cp -f "./.templates/compile/postrm"                      "../compile/postrm"

    cp -f "./.templates/compile/Manifest.${DEVELOP_EXT}"     "../compile/Makefile.${DEVELOP_EXT}"
    sedi "s|@APP_NAME|${APP_NAME}|g"                    "../compile/postinst"
    sedi "s|@APP_NAME|${APP_NAME}|g"                    "../compile/postrm"
    sedi "s|@APP_NAME|${APP_NAME}|g"                    "../tests/modules/hello.bats"

    prepare_makefile "${DEVELOP_EXT}"
}


#-------------------------------------------------------------------------------
#  Проверяем соответствия флага языка разработки и текущий манифест для сборки пакета
#-------------------------------------------------------------------------------
check_dev_language(){

    manifest_file=$(find .. -type f | grep "compile/Makefile" | head -1)

    if [ -n "${manifest_file}" ]; then
        if ! echo "${manifest_file}" | grep -qE ".${DEVELOP_EXT}$"; then
            echo -e "${RED}${PREF}Обнаружено несоответствие файлов проекта с заявленным языком разработки!${NOCL}"
            echo -e "${BLUE}${PREF}Файл манифеста: ${manifest_file}${NOCL}"
            set_dev_language
        fi
    else
        set_dev_language
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
#   Если система Linux
    fi

}


#-------------------------------------------------------------------------------
#  Получаем ID контейнера
#-------------------------------------------------------------------------------
get_container_id(){
    container_name=${1}
	docker_id=$(docker ps | grep "${container_name}" | head -1 | cut -d' ' -f1 )
	[ -z "${docker_id}" ] && docker_id=$(docker ps -a | grep "${container_name}" | head -1 | cut -d' ' -f1 )
	echo "${docker_id}"
}


#-------------------------------------------------------------------------------
#  Останавливаем и удаляем контейнер
#-------------------------------------------------------------------------------
purge_running_container(){
	container_id="${1}"
	docker stop "${container_id}"
	docker rm "${container_id}"
}

#-------------------------------------------------------------------------------
# Подключаемся к контейнеру когда он уже запущен
#-------------------------------------------------------------------------------
connect_when_run(){

   	script_to_run=${1}
   	run_with_root=${2}
   	docker_id=${3}
   	_user=${4}
   	container_name=${5}

   	echo "${_user}::Контейнер разработки '${container_name}' запущен."
    echo "${_user}::Производим подключение к контейнеру..."
    if [ -n "${script_to_run}" ] ; then
        docker_exec "${docker_id}" "${script_to_run}"
    else
        show_line
        if [ "${run_with_root}" = yes ]; then
            docker_exec "${docker_id}" "" "root"
        else
            docker_exec "${docker_id}"
        fi
    fi
}


#-------------------------------------------------------------------------------
# Подключаемся к контейнеру когда он уже остановлен, но существует
#-------------------------------------------------------------------------------
connect_when_stopped(){

    script_to_run=${1}
    run_with_root=${2}
    docker_id=${3}
    _user=${4}
    container_name=${5}

    echo "${_user}::Контейнер разработки '${container_name}' смонтирован, но остановлен."
    echo -n "${_user}::Запускаем контейнер и производим подключение к нему..."
    docker start "${docker_id}"
    show_line

    if [ -n "${script_to_run}" ] ; then
        docker_exec "${docker_id}" "${script_to_run}"
    else
        if [ "${run_with_root}" = yes ]; then
            docker_exec "${docker_id}" "" "root"
        else
            docker_exec "${docker_id}"
        fi
    fi
}

#-------------------------------------------------------------------------------
# Подключаемся к контейнеру, когда он не существует (не смонтирован)
#-------------------------------------------------------------------------------
connect_when_not_mounted(){

    script_to_run=${1}
    run_with_root=${2}
    _user=${3}
    container_name=${4}

    echo "${_user}::Контейнер '${container_name}' не смонтирован!"
    #	Если контейнер запущен или просто собран - удаляем его (так, как там могут быть ошибки)
    container_id="$(get_container_id "${container_name}")"
    [ -n "${container_id}" ] && purge_running_container "${container_id}" &> /dev/null

    echo "${_user}::Производим запуск и монтирование контейнера и подключаемся к нему..."

    if [ -n "${script_to_run}" ] ; then
        _uid_="${U_ID}"; _gid_="${G_ID}"
    else
        if [ "${run_with_root}" = yes ] ; then
            _uid_=root && _gid_=root
        else
            _uid_="${U_ID}"; _gid_="${G_ID}"
        fi

    fi
    echo "${PREF}ЗАХОДИМ ВНУТРЬ КОНТЕЙНЕРА '${container_name}'"
    docker_run "${script_to_run}" "${container_name}" "${arch}" "${_uid_}:${_gid_}"
}

#-------------------------------------------------------------------------------
# Собираем образ для запуска контейнера
#-------------------------------------------------------------------------------
build_image(){

    script_to_run=${1};
    container_name=${2};
    arch=${3}

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
        echo "${PREF}Запускаем сборку пакета в контейнере '${container_name}' ..."

        docker_run "${script_to_run}" "${container_name}" "${arch}" "${U_ID}:${G_ID}"

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

    container_id=$(docker ps --filter ancestor="${IMAGE_NAME}" -q)
    if [ -n "${container_id}" ] ; then
        docker stop "${container_id}" &>/dev/null
        docker rm "${container_id}"   &>/dev/null
    else
        container_id=$(docker ps -a --filter ancestor="${IMAGE_NAME}" -q)
        [ -n "${container_id}" ] && docker rm ${container_id} &> /dev/null
    fi

    docker image ls | grep -q "${IMAGE_NAME}" &&
        if docker image rm "${IMAGE_NAME}" &> /dev/null &&
           docker rmi $(docker image ls -q --filter dangling=true) &> /dev/null; then
                manager_container_to_make "${script_to_run}"; else
                manager_container_to_make "${script_to_run}"; fi

}

#-------------------------------------------------------------------------------
# Подключаемся к контейнеру для сборки приложения в нем
#-------------------------------------------------------------------------------
container_run_to_make(){
    script_to_run="${1}"
    run_with_root="${2}"
    container_name=${3}

    if [ "${run_with_root}" = yes ]; then _user=root; else _user=${USER}; fi
    docker_id=$(docker ps | grep -E "'""${container_name}""'" | head -1 | cut -d' ' -f1 )
    if [ -n "${docker_id}" ]; then
        connect_when_run "${script_to_run}" "${run_with_root}" "${docker_id}" "${_user}"
    else
        docker_id=$(docker ps -a | grep -E "'""${container_name}""'" | head -1 | cut -d' ' -f1 )
        if [ -n "${docker_id}" ]; then
            connect_when_stopped "${script_to_run}" "${run_with_root}" "${docker_id}" "${_user}"
        else
            if docker image ls | grep -q "${IMAGE_NAME}"; then
                connect_when_not_mounted "${script_to_run}" "${run_with_root}" "${_user}" "${container_name}"
            else
                build_image "${script_to_run}" "${container_name}" "${arch}"
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
	count=0; choice=''

    if is_mac_os_x ; then
        ps -x | grep 'Docker.app' | grep -vq grep || {
            echo -e "${PREF}${RED}Сервис Docker не запущен! Для запуска наберите команду 'open -a Docker'${NOCL}"
            show_line
            exit 1
        }
    fi
    if [[ "${APPS_LANGUAGE}" =~ BASH|bash|Bash|sh|SH|Sh ]] ; then
        container_run_to_make "${script_to_run}" "${run_with_root}" "$(get_container_name "all")"
        show_line
    else
        echo -e "Доступные ${BLUE}архитектуры${NOCL} для сборки:"
        show_line
        list_arch=$(arch_list); [ -n "${script_to_run}" ] && list_arch="$(arch_list) Все\tархитектуры"

        for arch in ${list_arch} ; do
            count=$((count+1))
            echo -e " ${count}. ${BLUE}${arch}${NOCL}"
        done
        show_line
        read_choice "Выберите номер позиции из списка: " "${count}" choice
        show_line
        if [ "${choice}" = q ] ; then exit 1;
        elif [ "${choice}" = ${count} ]; then
            for arch in $(arch_list); do
                container_run_to_make "${script_to_run}" "${run_with_root}" "$(get_container_name "${arch}")"
                show_line
            done
        else
            arch=$(echo "${list_arch}" | tr -s ' ' | cut -d' ' -f"${choice}")
            container_run_to_make "${script_to_run}" "${run_with_root}" "$(get_container_name "${arch}")"
            show_line
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
            set_version_part "VERSION"  "${ver_main}"
            set_version_part "STAGE"    "${ver_stage}"
            set_version_part "RELEASE"  "${ver_release}"
            full_ver=$(echo "${ver_main}${ver_stage}${ver_release}" | sed -e 's/[[:space:]]*$//' | tr ' ' '-')
            echo "${PREF}Версия пакета '${full_ver}' успешно установлена!"
        fi
    else
        ver_main="$(get_version_part     "VERSION")"
        ver_stage="$(get_version_part    "STAGE")"
        ver_release="$(get_version_part  "RELEASE")"
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
    sedi "s|DEBUG=.*$|DEBUG=${debug}|" ./scripts/package.app
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
check_system

args="$(set_debug_status "${*}")"

#   Сбрасываем в первоначальное состояние пакет до установки языка разработки
if [[ "${args}" =~ init|-in ]] ; then
    reset_data;
    exit 0;
else
    [[ "${args}" =~ rebuild|-rb ]] && reset_data
    check_dev_language ;
fi
case "${1}" in
	term|-tr )   	        manager_container_to_make "" ;;
	root|-rt) 		        manager_container_to_make "" "yes" ;;
	make*|-mk*|build*|-bl*)
	    mk_arg=$(echo "${1}" | cut -d' ' -f2-)
	    case  "${mk_arg}" in
	        ver* )          package_version_set "$(echo "${mk_arg//ver/}" | sed -e 's/^[[:space:]]*//')";;
	        * )             manager_container_to_make "${SCRIPT_TO_MAKE}" ;;
	    esac
	    ;;
	copy|-cp )  	        manager_container_to_make "${SCRIPT_TO_COPY}" ;;
    test|-ts )  	        manager_container_to_make "${SCRIPT_TO_TEST}" ;;
    rebuild|-rb)            rebuild_image "${SCRIPT_TO_MAKE}" ;;
    help|-h|--help)         show_help ;;
	*)                      echo -e "${RED}${PREF}Аргументы запуска скрипта не заданы, либо не верны!${NOCL}"
                            show_help ;;
esac


