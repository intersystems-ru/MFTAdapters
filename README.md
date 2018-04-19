# MFTAdapters
Additional services for MFT

# Yandex

1. Регистрируемся на Yandex.
2. [Создаём Yandex App](https://oauth.yandex.ru/client/new)
    - Выбираем платформу `Веб-сервисы`
    - Прописываем Redirect URI: `http://Host:Port/csp/sys/oauth2/OAuth2.Response.cls` (https, если UseSSL = 1)
    - Даём все права на `Яндекс.Диск REST API`
    - Получаем `ID`, `Pass`
3. Загружаем код, выполняем: `write $System.Status.GetErrorText(##class(MFT.Yandex).Install(Login, ID, Pass, Host, Port, UseSSL))`
    - Login - почта
    - Host, Port - хост и порт коллбэка авторизации
    - UseSSL - использовать ли SSL для коллбэка
4. Открываем `http://Host:Port/csp/sys/sec/%25CSP.UI.Portal.MFT.ConnectionList.zen`
5. Наживаем `Get Access Token`, авторизуем приложение.
6. Если всё хорошо, то Status будет Authorized.
7. Выполнить: `write $System.Status.GetErrorText(##class(MFT.Yandex).ConfigureProduction(yandexSource, fileDestination, fileSource, yandexDestination))`
    - `yandexSource` и `fileDestination` - папка Яндекс.Диска из которой скачиваются файлы и локальная папка в которую они записываются  
    - `fileSource` и `yandexDestination` - локальная папка из которой скачиваются файлы и папка Яндекс.Диска в которую они записываются 
    - Важно: папки Яндкс.Диска должны заканчиваться на `/`
8. Открыть продукцию `MFT.Production` и запустить её. 
9. Добавьте файл(ы) в `yandexSource` и `fileSource` для демонстрации работы.
