# MFTAdapters
Additional services for MFT

# Yandex

1. Зарегистрироваться на Yandex.
2. [Создать Yandex App](https://oauth.yandex.ru/client/new)
    - Выбирать платформу `Веб-сервисы`
    - Прописать Redirect URI: `http://Host:Port/csp/sys/oauth2/OAuth2.Response.cls` (https, если UseSSL = 1, для разработки можно указать  `http://localhost:57772/csp/sys/oauth2/OAuth2.Response.cls`)
    - Дать все права на `Яндекс.Диск REST API`
    - Записать `ID`, `Pass`
3. Загрузить код 
    - [Из релиза](https://github.com/intersystems-ru/MFTAdapters/releases)
    - Смонтировать базу `CACHELIB` на запись
    - Загрузить код в любую область с Interoperability
4. Выполнить: `write $System.Status.GetErrorText(##class(MFT.Yandex).Install(Login, ID, Pass, Host, Port, UseSSL))`
    - Login - почта
    - Host, Port - хост и порт коллбэка авторизации
    - UseSSL - использовать ли SSL для коллбэка
5. Открыть `http://Host:Port/csp/sys/sec/%25CSP.UI.Portal.MFT.ConnectionList.zen`
6. Нажать `Get Access Token`, авторизоваться.
7. Если всё хорошо, то Status будет Authorized.
8. Выполнить: `write $System.Status.GetErrorText(##class(MFT.Yandex).ConfigureProduction(yandexSource, fileDestination, fileSource, yandexDestination))`
    - `yandexSource` и `fileDestination` - папка Яндекс.Диска из которой скачиваются файлы и локальная папка в которую они записываются  
    - `fileSource` и `yandexDestination` - локальная папка из которой скачиваются файлы и папка Яндекс.Диска в которую они записываются 
    - Важно: папки Яндкс.Диска должны заканчиваться на `/` (например папка `out` в корне диска будет `/out/`)
9. Открыть продукцию `MFT.Production` и запустить её. 
10. Добавить файл(ы) в `yandexSource` и `fileSource` для демонстрации работы.
