#!/usr/local/bin/bats

#-------------------------------------------------------------------------------
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom
# the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
#
# bats-core is a continuation of bats. Copyright for portions of the bats-core
# project are held by Sam Stephenson, 2014 as part of the project bats,
# licensed under MIT: Copyright (c) 2014 Sam Stephenson
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom
# the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
#-------------------------------------------------------------------------------
#
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

. library

#-------------------------------------------------------------------------------
#
#	Тесты предназначены для запуска на удаленной машине
#	для из запуска на удаленной машине необходима функция
#	из библиотеки on_server,  соответственно для запуска
#	тестов необходимо предварительно установить свой пакет
#	на удаленной машине (роутере)!
#
#-------------------------------------------------------------------------------
#	Документация по пакету тестирования находится по ссылке
#   https://bats-core.readthedocs.io/en/stable/
#-------------------------------------------------------------------------------

@test "Проверка работы функции main()" {
    # Задаем команду для выполнения на стороне роутера
    # В нашем примере передаем имя проекта, как команду для исполнения
	# Исполняем команду для выполнения на стороне роутера
    run on_server "@APP_NAME"
	print_on_error "${status}" "${output}"

    # Проверяем на статус завершения команды
	[ "${status}" -eq 0 ]

	#	Блок проверок то, что точно должно быть при нормальной работе скрипта
	echo "${output}" | grep -q "Здравствуй Мир!"

}
@test "Проверка работы функции main()" {
    # Задаем команду для выполнения на стороне роутера
    # В нашем примере передаем имя проекта, как команду для исполнения
	# Исполняем команду для выполнения на стороне роутера
    run on_server "@APP_NAME"
	print_on_error "${status}" "${output}"

    # Проверяем на статус завершения команды
	[ "${status}" -eq 0 ]

	#	Блок проверок то, что точно должно быть при нормальной работе скрипта
	echo "${output}" | grep -q "Здравствуй Мир!"

}
@test "Проверка работы функции main()" {
    # Задаем команду для выполнения на стороне роутера
    # В нашем примере передаем имя проекта, как команду для исполнения
	# Исполняем команду для выполнения на стороне роутера
    run on_server "@APP_NAME"
	print_on_error "${status}" "${output}"

    # Проверяем на статус завершения команды
	[ "${status}" -eq 0 ]

	#	Блок проверок то, что точно должно быть при нормальной работе скрипта
	echo "${output}" | grep -q "Здравствуй Мир!"

}
