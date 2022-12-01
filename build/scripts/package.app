#! /usr/bin/env bash
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
#----------------------------------------------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Сохраняем данные из файлов ./compile/postinst ./compile/postrm в файл манифеста  /compile/Makefile.<ext>
#----------------------------------------------------------------------------------------------------------------------
save_post_blocks(){

    extension=$(echo "${APPS_LANGUAGE}" | tr "[:upper:]" "[:lower:]")
    make_file="${APPS_ROOT}/${APP_NAME}/compile/Makefile.${extension}"
    make_file_tmp="${make_file}.tmp"
    post_inst=$(cat < "${APPS_ROOT}/${APP_NAME}/compile/postinst")
    post_term=$(cat < "${APPS_ROOT}/${APP_NAME}/compile/postrm")


    cat < "${make_file}" \
        | sed '/postinst/,/endef/ { /postinst/n; /postrm/n; {/.*/d;};};' \
        | sed 's/\(.*postinst\)/\1\n\t@POSTINST\nendef/' \
        | sed '/postrm/,/endef/ { /postrm/n; {/.*/d;};};' \
        | sed 's/\(.*postrm\)/\1\n\t@POSTRM\nendef/' > "${make_file_tmp}"

    awk -i inplace -v r="${post_inst}" '{gsub(/@POSTINST/,r)}1' "${make_file_tmp}"
    awk -i inplace -v r="${post_term}" '{gsub(/@POSTRM/,r)}1' "${make_file_tmp}"

    mv -f "${make_file_tmp}" "${make_file}"
    cp "${make_file}" "${APP_MAKE_BUILD_PATH}/Makefile"
}

#----------------------------------------------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Производим первую сборку toolchain в контейнере
# В случае необходимости устанавливаем флаг отладки в YES
#----------------------------------------------------------------------------------------------------------------------



cp -rf "${APPS_ROOT}/${APP_NAME}/code/." "${APP_MAKE_BUILD_PATH}/files"
save_post_blocks

cat ${APPS_ROOT}/${APP_NAME}/compile/Makefile.cpp
exit
show_line
echo "${PREF}Задействовано ${np} яд. процессора."
echo "${PREF}Опции отладки: DEBUG = ${DEBUG}, ${deb}"
echo "${PREF}Makefile успешно импортирован."
echo "${PREF}Собираем пакет ${APP_NAME} вер. ${FULL_VERSION}"
show_line
echo "${PREF}Сборка запущена: $(zdump EST-3)"; show_line

rm -f "$(get_ipk_package_file)"
cd "${APPS_ROOT}/entware/"

if ! grep -q "${APP_NAME}" "${APPS_ROOT}/entware/.config" ; then

	make oldconfig <<< m
	make tools/install ${deb}
	make toolchain/install ${deb}
fi

[[ "${*}" =~ menu|-mc ]] && make menuconfig
make package/"${APP_NAME}"/{clean,compile} ${deb}

# Меняем версию пакета в файлах сборки
# настраивается под конкретный собираемый пакет
#change_version_in_package

# копируем собранный пакет в папку где хранятся все сборки
[ -d "${APPS_ROOT}/${APP_NAME}/ipk" ] || mkdir -p "${APPS_ROOT}/${APP_NAME}/ipk"
cp "$(get_ipk_package_file)" "${APPS_ROOT}/${APP_NAME}/ipk"

show_line
app_tar_name=$(get_ipk_package_file)
# копируем собранный пакет на роутер
copy_app_to_router "$(get_ipk_package_file)" "${app_tar_name}"
run_reinstalation_on_router "${app_tar_name}"
# run_tests
echo "Сборка завершена: $(zdump EST-3)";

# Запускаем тесты
show_line
ask_run_tests