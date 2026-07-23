@echo off
setlocal
:: можно параметром указать текст сообщения для commit

:: 1. Имя главного скрипта - исправить на нужное имя!!!
set verFile=edge.py

:: 2. Извлекаем версию
for /f "usebackq tokens=*" %%a in (`python -c "import re; f=open('%verFile%', encoding='utf-8'); print(re.search(r'__version__\s*=\s*[\x27\x22]([^\x27\x22]+)', f.read()).group(1))"`) do (set vers=%%a)
set vers=%vers:"=%

:: 3. Формируем сообщение коммита
:: %1 - это первый аргумент, переданный при запуске скрипта
if "%~1"=="" (
    set commitMsg=Обновление версии %vers%
) else (
    set commitMsg=Обновление версии %vers%: %~1
)

echo Сообщение коммита: "%commitMsg%"

:: 4. Выполняем синхронизацию
git add .
git commit -m "%commitMsg%"
git push -q

echo --- Синхронизация завершена ---