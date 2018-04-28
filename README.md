# MFTAdapters


Additional services for MFT. [Community article](https://community.intersystems.com/post/adding-your-own-provider-mft).

# Installation

1. Download and import [Installer](https://raw.githubusercontent.com/intersystems-ru/MFTAdapters/master/MFT/Installer.cls) into any Interoperability-enabled namespace.
2. Execute: `write $System.Status.GetErrorText(##class(MFT.Installer).Install())`

# Yandex

1. Register on Yandex.
2. [Create Yandex App](https://oauth.yandex.ru/client/new).
    - Check `Веб-сервисы`
    - Set Redirect URI: `http://Host:Port/csp/sys/oauth2/OAuth2.Response.cls` (https, if UseSSL = 1, for development you can set it to `http://localhost:57772/csp/sys/oauth2/OAuth2.Response.cls`)
    - Give disk access `Яндекс.Диск REST API`
    - Get `ID`, `Pass`
3. Execute: `write $System.Status.GetErrorText(##class(MFT.Yandex).Install(Login, ID, Pass, Host, Port, UseSSL))`
    - Login - your Yandex email
    - Host, Port - same as a callback
    - UseSSL - use SSL for callback? Your server needs to support https
4. Open `http://Host:Port/csp/sys/sec/%25CSP.UI.Portal.MFT.ConnectionList.zen`
5. Press `Get Access Token` and complete authorization.
6. If everything went fine the Status would be Authorized.
7. Execute: `write $System.Status.GetErrorText(##class(MFT.Yandex).ConfigureProduction(yandexSource, fileDestination, fileSource, yandexDestination))`
    - `yandexSource` и `fileDestination` - Yandex.Disk folder to download files from, they are stored in a local destination folder.
    - `fileSource` и `yandexDestination` - local folder from which files are uploaded to Yandex.Disk.
    - Important: Yandex.Disk folder names should end with `/` (i.e. `out` in a disk root would be `/out/`)
8. Open production `MFT.Production` and start it. 
9. Add file(s) to `yandexSource` and `fileSource` to see how it works.


# Установка

1. Загрузить [Installer](https://raw.githubusercontent.com/intersystems-ru/MFTAdapters/master/MFT/Installer.cls) в любую область с Interoperability.
2. Выполнить: `write $System.Status.GetErrorText(##class(MFT.Installer).Install())`

# Yandex

1. Зарегистрироваться на Yandex.
2. [Создать Yandex App](https://oauth.yandex.ru/client/new).
    - Выбирать платформу `Веб-сервисы`
    - Прописать Redirect URI: `http://Host:Port/csp/sys/oauth2/OAuth2.Response.cls` (https, если UseSSL = 1, для разработки можно указать  `http://localhost:57772/csp/sys/oauth2/OAuth2.Response.cls`)
    - Дать все права на `Яндекс.Диск REST API`
    - Записать `ID`, `Pass`
3. Выполнить: `write $System.Status.GetErrorText(##class(MFT.Yandex).Install(Login, ID, Pass, Host, Port, UseSSL))`
    - Login - почта
    - Host, Port - хост и порт коллбэка авторизации
    - UseSSL - использовать ли SSL для коллбэка
4. Открыть `http://Host:Port/csp/sys/sec/%25CSP.UI.Portal.MFT.ConnectionList.zen`
5. Нажать `Get Access Token`, авторизоваться.
6. Если всё хорошо, то Status будет Authorized.
7. Выполнить: `write $System.Status.GetErrorText(##class(MFT.Yandex).ConfigureProduction(yandexSource, fileDestination, fileSource, yandexDestination))`
    - `yandexSource` и `fileDestination` - папка Яндекс.Диска из которой скачиваются файлы и локальная папка в которую они записываются  
    - `fileSource` и `yandexDestination` - локальная папка из которой скачиваются файлы и папка Яндекс.Диска в которую они записываются 
    - Важно: папки Яндкс.Диска должны заканчиваться на `/` (например папка `out` в корне диска будет `/out/`)
8. Открыть продукцию `MFT.Production` и запустить её. 
9. Добавить файл(ы) в `yandexSource` и `fileSource` для демонстрации работы.

# Notes

[Список OAuth приложений Яндекса](https://oauth.yandex.ru/).
