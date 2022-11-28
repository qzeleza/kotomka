#!/bin/bash
set -e

RED="\033[1;31m";
BLUE="\033[36m";
NOCL="\033[m";

[[ "$(pwd)" =~ '\/build' ]] || {
    echo -e "${RED}>> Запуск скрипа возможен только из папки проекта ./build${NOCL}."
    exit 1
}

. ./CONFIG

#----------------------------------------------------------------------------------------------------------------------
# Печатаем строку из 100  знаков равно
#----------------------------------------------------------------------------------------------------------------------
show_line(){
    if [ -z "${1}" ] ; then printf "=%.s" {1..100} ; else printf "-%.s" {1..100} ; fi
    printf '\n'
}
#----------------------------------------------------------------------------------------------------------------------
# Получаем необходимую информацию о версии пакета
#----------------------------------------------------------------------------------------------------------------------
get_version_part(){
	value=${1}
	echo "$(pwd)/version"
	cat < "$(pwd)/version" | grep "${value}" | cut -d'=' -f2
}

#----------------------------------------------------------------------------------------------------------------------
VERSION=$(get_version_part VERSION)
STAGE=$(get_version_part STAGE)
RELEASE=$(get_version_part RELEASE)
#----------------------------------------------------------------------------------------------------------------------
if [ -n "${STAGE}" ]; then FULL_VERSION="${VERSION} ${STAGE} ${RELEASE}"; else FULL_VERSION="${VERSION} ${RELEASE}"; fi
#----------------------------------------------------------------------------------------------------------------------

DEBUG=YES										# флаг отладки процесса сборки образа
#----------------------------------------------------------------------------------------------------------------------
APP_NAME=$(pwd | sed "s/.*\\${APPS_ROOT}\/\(.*\).*$/\1/;" | cut -d'/' -f1)
IMAGE_NAME=$(echo "${DOCKER_ACCOUNT_NAME}" | tr "[:upper:]" "[:lower:]")/${APP_NAME}-dev
CONTAINER_NAME=${APP_NAME}

#----------------------------------------------------------------------------------------------------------------------
#	Пути к файлам на машине разработчика
#----------------------------------------------------------------------------------------------------------------------
DOCKER_FILES_PATH=$(pwd)/docker
ENV_FILE=${DOCKER_FILES_PATH}/.env
DOCKER_COMP_FILE=${DOCKER_FILES_PATH}/docker-compose.yml
DOCKER_FILE=${DOCKER_FILES_PATH}/Dockerfile
DEVELOP_EXT=$(echo "${APPS_LANGUAGE}" | tr "[:upper:]" "[:lower:]")

#----------------------------------------------------------------------------------------------------------------------
#	Пути к файлам внутри контейнера
#----------------------------------------------------------------------------------------------------------------------
SCRIPTS_PATH=${APPS_ROOT}/${APP_NAME}/build/scripts
SCRIPT_TO_MAKE=${SCRIPTS_PATH}/package.app
SCRIPT_TO_COPY=${SCRIPTS_PATH}/copy.app

create_env_file(){
#----------------------------------------------------------------------------------------------------------------------
#	Записываем данные в файл .env для docker-compose
#----------------------------------------------------------------------------------------------------------------------
cat <<EOF > "${ENV_FILE}"
APP_NAME=${APP_NAME}
APPS_ROOT=${APPS_ROOT}
IMAGE_NAME=${IMAGE_NAME}
CONTAINER_NAME=${APP_NAME}
USER=${USER}
GROUP=${GROUP}
UID=${U_ID}
GID=${G_ID}
DEBUG=${DEBUG}
EOF
}

#----------------------------------------------------------------------------------------------------------------------
#  Сбрасываем в первоначальное состояние пакет до установки языка разработки.
#----------------------------------------------------------------------------------------------------------------------
reset_data(){
    rm -f "../code/main.${DEVELOP_EXT}" \
          "../code/Makefile" \
          "../code/main.sh" \
          "../make/Makefile.${DEVELOP_EXT}"
    echo -e "${RED}Пакет сброшен в первоначальное состояние, до установки языка разработки.${NOCL}"
    show_line
}


#----------------------------------------------------------------------------------------------------------------------
#  Производим первоначальные настройки пакета в зависимости от заявленного языка разработки
#----------------------------------------------------------------------------------------------------------------------
set_dev_language(){

    echo -e "${BLUE}Заявленным языком разработки является ${DEVELOP_EXT}${NOCL}"
    echo -e "${BLUE}Производим замену файлов в соответствии с установками в ./build/CONFIG ${NOCL}"

    case ${DEVELOP_EXT} in
        cpp|CPP|c|C)
            cp -f "./.templates/Makefiles/Makefile.${DEVELOP_EXT}" "../code/Makefile.${DEVELOP_EXT}"
            sed -i '' "s|@APP_NAME|${APP_NAME}|g"                  "../code/Makefile.${DEVELOP_EXT}"
            cp -f "./.templates/sources/main.${DEVELOP_EXT}"       "../code/main.${DEVELOP_EXT}"
            ;;
        BASH|bash)
            cp "./.templates/sources/main.sh" "../code/main.sh"
            ;;
        *)
            show_line
            echo -e "${RED}Не распознан язык разработки в файле ./build/CONFIG${NOCL}"
            echo -e "${BLUE}Текущее значение APPS_LANGUAGE = ${APPS_LANGUAGE}.${NOCL}"
            echo -e "${BLUE}Задайте одно из значений: C, CPP или BASH.${NOCL}"
            show_line
            exit 1
            ;;
    esac
    cp -f "./.templates/Manifests/postinst" "../make/postinst"
    cp -f "./.templates/Manifests/postrm" "../make/postrm"

    cp -f "./.templates/Manifests/Manifest.${DEVELOP_EXT}"      "../make/Makefile.${DEVELOP_EXT}"
    sed -i '' "s|@APP_NAME|${APP_NAME}|g" "../make/postinst"
    sed -i '' "s|@APP_NAME|${APP_NAME}|g" "../make/postrm"
}


#----------------------------------------------------------------------------------------------------------------------
#  Проверяем соответствия флага языка разработки и текущий манифест для сборки пакета
#----------------------------------------------------------------------------------------------------------------------
check_dev_language(){

    manifest_file=$(find .. -type f | grep "make/Makefile" | head -1)

    if [ -n "${manifest_file}" ]; then
        if ! echo "${manifest_file}" | grep -qE ".${DEVELOP_EXT}$"; then
            echo -e "${RED}Обнаружено несоответствие файлов проекта с заявленным языком разработки!${NOCL}"
            echo -e "${BLUE}Файл манифеста: ${manifest_file}${NOCL}"
            set_dev_language
        fi
    else
        set_dev_language
    fi
}


#----------------------------------------------------------------------------------------------------------------------
#  Получаем ID контейнера
#----------------------------------------------------------------------------------------------------------------------
get_container_id(){
	docker_id=$(docker ps | grep "${CONTAINER_NAME}" | head -1 | cut -d' ' -f1 )
	[ -z "${docker_id}" ] && docker_id=$(docker ps | grep "${CONTAINER_NAME}" | head -1 | cut -d' ' -f1 )
	echo "${docker_id}"
}


#----------------------------------------------------------------------------------------------------------------------
#  Останавливаем и удаляем контейнер
#----------------------------------------------------------------------------------------------------------------------
purge_running_container(){
	container_id="${1}"
	docker stop "${container_id}"
	docker rm "${container_id}"
}

#----------------------------------------------------------------------------------------------------------------------
# Подключаемся к контейнеру когда он уже запущен
#----------------------------------------------------------------------------------------------------------------------
connect_when_run(){

   	script_to_run=${1}
   	run_with_root=${2}
   	docker_id=${3}
   	_user=${4}

   	echo "${_user}::Контейнер разработки ${CONTAINER_NAME}[${docker_id}] запущен."
    echo "${_user}::Производим подключение к контейнеру."
    if [ -n "${script_to_run}" ] ; then
        docker exec -w "${APPS_ROOT}/${APP_NAME}/build" -it "${docker_id}" /bin/bash "${script_to_run}"
    else
        show_line
        if [ "${run_with_root}" = yes ]; then
            docker exec -w "${APPS_ROOT}/${APP_NAME}/build" -it --user root:root "${docker_id}" /bin/bash
        else
            docker exec -w "${APPS_ROOT}/${APP_NAME}/build" -it "${docker_id}" /bin/bash
        fi
    fi
}


#----------------------------------------------------------------------------------------------------------------------
# Подключаемся к контейнеру когда он уже остановлен, но существует
#----------------------------------------------------------------------------------------------------------------------
connect_when_stopped(){

    script_to_run=${1}
    run_with_root=${2}
    docker_id=${3}
    _user=${4}

    echo "${_user}::Контейнер разработки '${CONTAINER_NAME}' смонтирован, но остановлен."
    echo -n "${_user}::Запускаем контейнер и производим подключение к нему... id="
    docker start "${docker_id}"
    show_line

    if [ -n "${script_to_run}" ] ; then
        docker exec -w "${APPS_ROOT}/${APP_NAME}/build" -it "${docker_id}" /bin/bash "${script_to_run}"
    else
        if [ "${run_with_root}" = yes ]; then
            docker exec -w "${APPS_ROOT}/${APP_NAME}/build" -it --user root:root "${docker_id}" /bin/bash
        else
            docker exec -w "${APPS_ROOT}/${APP_NAME}/build" -it "${docker_id}" /bin/bash
        fi
    fi
}

#----------------------------------------------------------------------------------------------------------------------
# Подключаемся к контейнеру, когда он не существует (не смонтирован)
#----------------------------------------------------------------------------------------------------------------------
connect_when_not_mounted(){

    script_to_run=${1}
    run_with_root=${2}
    _user=${3}

    echo "${_user}::Контейнер ${CONTAINER_NAME} не смонтирован!"
    #	Если контейнер запущен или просто собран - удаляем его (так, как там могут быть ошибки)
    container_id="$(get_container_id)"
    [ -n "${container_id}" ] && purge_running_container "${container_id}" &> /dev/null

    echo "${_user}::Производим запуск и монтирование контейнера и подключаемся к нему..."
    version_txt="v$(echo "${FULL_VERSION} "| tr -s ' ' '-')"

    if [ -n "${script_to_run}" ] ; then
        _uid_="${_UID}"; _gid_="${_GID}"
    else
        if [ "${run_with_root}" = yes ] ; then
            _uid_=root && _gid_=root
        else
            _uid_="${_UID}"; _gid_="${_GID}"
        fi

    fi
    echo "ЗАХОДИМ ВНУТРЬ КОНТЕЙНЕРА ${APP_NAME}"
    docker run -it --user "${_uid_}:${_gid_}" --name "${CONTAINER_NAME}" \
               --mount type=bind,src="$(dirname "$(pwd)")",dst="${APPS_ROOT}"/"${APP_NAME}" \
               "${IMAGE_NAME}" /bin/bash

#    сохраняем изменения во вновь созданном контейнере
    ${?} && docker commit "${CONTAINER_NAME}" "${IMAGE_NAME}:${version_txt}"

}

#----------------------------------------------------------------------------------------------------------------------
# Собираем образ для запуска контейнера
#----------------------------------------------------------------------------------------------------------------------
image_build(){
    # удаляем старые контейнеры
#    docker container prune -f
    script_to_run=${1}
    if ! docker ps | grep -q "${APP_NAME}" ; then
    #	то заходим внутрь контейнера и сразу запускаем сборку пакета
    #	если не создан образ, то запускаем сборку образа
        show_line;
        echo -e "${RED}Cборка образа может занять до 3 минут.${NOCL}"
        echo "Запускаем сборку НОВОГО образа ${IMAGE_NAME}"
        show_line
        dev_path=$(dirname "$(pwd)")
        sed -i '' "s|.*-.*:.*{APPS_ROOT}.*{APP_NAME}|        - ${dev_path//\//\\/}:\${APPS_ROOT}\/\${APP_NAME}|g; \
            s|dockerfile:.*$|dockerfile: ${DOCKER_FILE}|" \
            "${DOCKER_COMP_FILE}"
        docker-compose -f "${DOCKER_COMP_FILE}" up --build -d
        show_line
    fi

    if [ "${?}" = 0 ]; then
        echo "Docker-образ собран без ошибок."
        echo "Запускаем сборку пакета в самом контейнере..."
        docker exec -w "${APPS_ROOT}/${APP_NAME}/build" --user "${USER}:${GROUP}" -it "${APP_NAME}" /bin/bash "${script_to_run}"
        rm -f "${ENV_FILE}"
    else
        show_line; echo "Docker-образ собран с ошибками!"
        exit 1
    fi
    show_line
}


#----------------------------------------------------------------------------------------------------------------------
# Удаляем готовый образ и собираем его заново для запуска контейнера
#----------------------------------------------------------------------------------------------------------------------
image_rebuild(){
    echo "Удаляем предыдущий образ ${IMAGE_NAME}"
    script_to_run=${1}

    container_id=$(docker ps --filter ancestor="${IMAGE_NAME}" -q)
    if [ -n "${container_id}" ] ; then
        docker stop "${container_id}" &>/dev/null
        docker rm "${container_id}"   &>/dev/null
    else
        container_id=$(docker ps -a --filter ancestor="${IMAGE_NAME}" -q)
        [ -n "${container_id}" ] && docker rm "${container_id}"
    fi

    docker image ls | grep -q "${IMAGE_NAME}" && docker image rm "${IMAGE_NAME}"
    image_build "${script_to_run}"
}



#----------------------------------------------------------------------------------------------------------------------
# Подключаемся к контейнеру для сборки приложения в нем
#----------------------------------------------------------------------------------------------------------------------
manager_container_to_make(){

	script_to_run="${1}"
	run_with_root="${2:-no}"

    if [ "${run_with_root}" = yes ]; then _user=root; else _user=${USER}; fi
	docker_id=$(docker ps | grep "${CONTAINER_NAME}" | head -1 | cut -d' ' -f1 )
	if [ -n "${docker_id}" ]; then
	    connect_when_run "${script_to_run}" "${run_with_root}" "${docker_id}" "${_user}"
	else
		docker_id=$(docker ps -a | grep "${CONTAINER_NAME}" | head -1 | cut -d' ' -f1 )
		if [ -n "${docker_id}" ]; then
		    connect_when_stopped "${script_to_run}" "${run_with_root}" "${docker_id}" "${_user}"
		else
		    if docker image ls | grep -q "${IMAGE_NAME}"; then
                connect_when_not_mounted "${script_to_run}" "${run_with_root}" "${_user}"
            else
                create_env_file
                image_build "${script_to_run}"
            fi
		fi
	fi
	show_line
}

set_debug_status(){
    if echo "${*}" | grep -qE '\-db|debug' ; then
        debug=YES
    else
        debug=NO
    fi
   sed -i '' "s|DEBUG=.*$|DEBUG=${debug}|" ./scripts/package.app
   echo "${*}" | sed "s/-v//g; s/-deb//g; s/-d//g;" | tr -d ' '
}

#----------------------------------------------------------------------------------------------------------------------
# Удаляем готовый образ и собираем его заново для запуска контейнера
#----------------------------------------------------------------------------------------------------------------------
show_help(){
    echo -e "${BLUE}Аргументы для запуска:${NOCL}"
    show_line
    echo "rebuild [-rb] - Удаляем готовый образ и собираем его заново с последующим запуском сборки пакета"
    echo "build   [-bl] - сборка образа и последующий запуск сборки пакета"
    echo "make    [-mk] - сборка пакета и копирование его на роутер"
    echo "copy    [-cp] - копирование уже собранного пакета на роутер"
    echo "term    [-tm] - подключение к контейнеру без исполнения скриптов под '${USER}'."
    echo "root    [-rt] - подключение к контейнеру без исполнения скриптов под root"
    echo "debug   [-db] - дополнительный флаг к предыдущим аргументам для запуска в режиме отладки"
    show_line "-"
    echo -e "Примеры запуска:"
    show_line "-"
    echo  " ./run.me build      - запускаем сборку среды разработки и первоначальную сборку пакета."
    echo  " ./run.me -mk -db    - запускаем сборку пакета с опцией отладки."
    echo  " ./run.me -cp        - копируем уже ранее собранный пакет на удаленное устройство (роутер)."
    echo  " ./run.me term       - заходим в ранее собранный контейнер под именем разработчика."
    show_line
}

show_line
args="$(set_debug_status "${*}")"

#   Сбрасываем в первоначальное состояние пакет до установки языка разработки
if [[ "${args}" =~ data_init ]] ; then reset_data; else check_dev_language ; fi

case "${args}" in
	term|run|-tm ) 	    manager_container_to_make "" ;;
	root|-rt) 		    manager_container_to_make "" "yes" ;;
	make|-mk) 		    manager_container_to_make "${SCRIPT_TO_MAKE}" ;;
	copy|-cp )  	    manager_container_to_make "${SCRIPT_TO_COPY}" ;;
    build|-bl)          create_env_file && image_build "${SCRIPT_TO_MAKE}" ;;
    rebuild|-rb)        create_env_file && image_rebuild "${SCRIPT_TO_MAKE}" ;;
    help|-h|--help)     show_help;;
    data_init)          ;;
	*)                  echo -e "${RED}Не заданы аргументы запуска скрипта!${NOCL}"
	                    show_line
                        show_help
    ;;
esac


