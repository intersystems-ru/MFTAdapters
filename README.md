# MFTAdapters
Additional services for MFT

# Yandex

1. Регистрируемся на Yandex.
2. [Создаём Yandex App](https://oauth.yandex.ru/client/new)
    - Выбираем платформу `Веб-сервисы`
    - Прописываем Redirect URI: `http://Host:Port/csp/sys/oauth2/OAuth2.Response.cls` (https, если UseSSL = 1, для разработки можно указать  `http://localhost:57772/csp/sys/oauth2/OAuth2.Response.cls`)
    - Даём все права на `Яндекс.Диск REST API`
    - Получаем `ID`, `Pass`
3. Загружаем код 
    - [Из релиза](https://github.com/intersystems-ru/MFTAdapters/releases)
    - Монтируем базу `CACHELIB` на запись
    - Загружаем код в любую область с Interoperability
4. Выполняем: `write $System.Status.GetErrorText(##class(MFT.Yandex).Install(Login, ID, Pass, Host, Port, UseSSL))`
    - Login - почта
    - Host, Port - хост и порт коллбэка авторизации
    - UseSSL - использовать ли SSL для коллбэка
5. Открываем `http://Host:Port/csp/sys/sec/%25CSP.UI.Portal.MFT.ConnectionList.zen`
6. Нажимаем `Get Access Token`, авторизуем приложение.
7. Если всё хорошо, то Status будет Authorized.
8. Выполнить: `write $System.Status.GetErrorText(##class(MFT.Yandex).ConfigureProduction(yandexSource, fileDestination, fileSource, yandexDestination))`
    - `yandexSource` и `fileDestination` - папка Яндекс.Диска из которой скачиваются файлы и локальная папка в которую они записываются  
    - `fileSource` и `yandexDestination` - локальная папка из которой скачиваются файлы и папка Яндекс.Диска в которую они записываются 
    - Важно: папки Яндкс.Диска должны заканчиваться на `/`
9. Открыть продукцию `MFT.Production` и запустить её. 
10. Добавьте файл(ы) в `yandexSource` и `fileSource` для демонстрации работы.
