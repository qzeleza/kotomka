#! /usr/bin/env bash

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
echo "Задействовано ${np} яд. процессора."
echo "Опции отладки: DEBUG = ${DEBUG}, ${deb}"
/apps/"${APP_NAME}"/build/scripts/Makefile.app
echo "Собираем пакет ${APP_NAME} вер. ${FULL_VERSION}"
show_line
echo "Сборка запущена: $(zdump EST-3)"; show_line

rm -f "${APP_PKG_FILE}"
cd /apps/entware/

if ! grep -q "${APP_NAME}" /apps/entware/.config ; then

	make oldconfig <<< m
	#sed -i 's/^\(CONFIG_PACKAGE_plato=\)\(.*$\)/\1m/' /apps/entware/.config
	make tools/install "${deb}"
	make toolchain/install "${deb}"
#	копируем ключи на роутер
	copy_ssh_keys_to_router;
fi

[[ "${*}" =~ menu|-mc ]] && make menuconfig
make package/utils/"${APP_NAME}"/{clean,compile} ${deb}

# Меняем версию пакета в файлах сборки
# настраивается под конкретный собираемый пакет
#change_version_in_package

# копируем собранный пакет в папку где хранятся все сборки
cp "${APP_PKG_FILE}" "/apps/${APP_NAME}/ipk"

show_line
# копируем собранный пакет на роутер
copy_app_to_router "${APP_PKG_FILE}" "${APP_TAR_NAME}"
run_reinstalation_on_router "${APP_TAR_NAME}"
# run_tests
echo "Сборка завершена: $(zdump EST-3)";
