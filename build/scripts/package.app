#! /usr/bin/env bash
PREF='>> '
set -e
BASEDIR=$(dirname "$(dirname "${0}")")
. "${BASEDIR}/scripts/library" "${BASEDIR}"
DEBUG=NO

if echo "${DEBUG}" | grep -qE 'YES|yes'; then
    deb="-j1 V=sc";
    np=1;
else
    deb="-j$(nproc)";
    np="$(nproc)";
fi

#----------------------------------------------------------------------------------------------------------------------
# ИСПОЛНЯЕМ ВНУТРИ КОНТЕЙНЕРА !!!
# Производим первую сборку toolchain в контейнере
# В случае необходимости устанавливаем флаг отладки в YES
#----------------------------------------------------------------------------------------------------------------------

show_line
echo "${PREF}Задействовано ${np} яд. процессора."
echo "${PREF}Опции отладки: DEBUG = ${DEBUG}, ${deb}"
echo "${PREF}Собираем пакет ${APP_NAME} вер. ${FULL_VERSION}"
show_line
echo "${PREF}Сборка запущена: $(zdump EST-3)"; show_line

rm -f "$(get_ipk_package_file)"
cd /apps/entware/

if ! grep -q "${APP_NAME}" /apps/entware/.config ; then

	make oldconfig <<< m
	make tools/install "${deb}"
	make toolchain/install "${deb}"
fi

[[ "${*}" =~ menu|-mc ]] && make menuconfig
make package/"${APP_NAME}"/{clean,compile} ${deb}

# Меняем версию пакета в файлах сборки
# настраивается под конкретный собираемый пакет
#change_version_in_package

# копируем собранный пакет в папку где хранятся все сборки
[ -d "/apps/${APP_NAME}/ipk" ] || mkdir -p "/apps/${APP_NAME}/ipk"
cp "$(get_ipk_package_file)" "/apps/${APP_NAME}/ipk"

show_line
app_tar_name=$(get_ipk_package_file)
# копируем собранный пакет на роутер
copy_app_to_router "$(get_ipk_package_file)" "${app_tar_name}"
run_reinstalation_on_router "${app_tar_name}"
# run_tests
echo "Сборка завершена: $(zdump EST-3)";
