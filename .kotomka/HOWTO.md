### Инструкция по запуску Котомки 

> Все действия по запуску пакета должны проводиться на отдельной машине c **Linux**, который поддерживает систему пакетов **apt** (**Debian** подобные)

1. Заходим по **ssh** на машину, на которой планируем развернуть сборку пакетов
2. Устанавливаем пакет curl, если его нет командой `apt install curl`
3. Производим установку пакета командой<br>
   `curl -JOLs  https://cutt.ly/kotomka && sh kotomka yes`<br>
    Этой командой будет произведена установка пакета и осуществлена сборка пакета для всех платформ. Таким образом будут сформированы необходимые контейнеры для всех архитектур.
4. Если у Вас нет необходимости в первоначальной подготовке имиджей для каждой из архитектур, то запускаем туже команду, но без ключа `yes`
5. После настройки пакета, Вы получите в выбранной папке (которую введете при установке пакета) готовую структуру для работы в папке `.code`
6. В папке `./code/scr` - хранятся Ваши исходные файлы для сборки пакета
7. В папке `./packages` - будут сохранятся Ваши собранные пакеты под каждую из архитектур
8. В папке `./tests` - будут хранится Ваши тесты для собираемого пакета
9. Основной файл для сборки это `./build.ru`. Детали его запуска смотрите по команде `./build.ru help` 
