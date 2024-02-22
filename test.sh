#!/bin/bash

. ./.kotomka/scripts/libraries/screen
set_esc_colors
set_esc_sims
set_esc_eraser
set_esc_cursor

. ./.kotomka/scripts/libraries/status
#. ./.kotomka/scripts/libraries/traps
set +E  # Отключить режим ERR в команде trap
set +e  # Отключить режим errexit
set +u  # Отключить режим nounset
set +o pipefail  # Отключить режим pipefail

err="Ошибка работы программы
Очень неприятные последствия"

print_line
ready "Проверка работы..."
find /opt | grep 4323432 && when_ok "ГОТОВО" || when_err "Проблема" "${err}"
print_line
#>/dev/null 2>&1
