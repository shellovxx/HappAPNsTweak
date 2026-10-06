# HappAPNsTweak

Твик для Happ на rootless iOS 16.4+ с ElleKit.

Исходники: `HappVPNPushRoute.c` и `HappAPNsDNS.c`.

Сборка с установленным [Theos](https://theos.dev/docs/installation):

```sh
make clean package
```

Готовый `.deb` появится в `packages/`. Пакеты и результаты сборки исключены из Git.
Для релиза прикрепляйте `.deb` к соответствующему тегу.

После установки перезапустите Happ и переподключите VPN.
