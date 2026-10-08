# Happ APNs Tweak — RootHide

Версия **1.5.0**, архитектура пакета `iphoneos-arm64e`. Собраны подписанные arm64 и современные arm64e PAC00 slices. Проверено на iPhone 11 Pro Max, iOS 16.6.1, Relaxin / RootHide / ElleKit.

Три модуля используют Logos с генератором MobileSubstrate; установленный ElleKit выполняет хуки. Диагностические логи из модулей удалены, сборка использует `FINALPACKAGE=1 DEBUG=0`.

- `HappVPNPushRoute.xm` задаёт флаги профиля: `includeAllNetworks=false`, `enforceRoutes=false`, `excludeAPNs=false`, `excludeLocalNetworks=true`, включая сохранение профиля.
- `HappAPNsDNS.xm` преобразует DoH-настройки туннеля в обычные DNS-настройки с теми же серверами, доменами и `matchDomainsNoSearch`.
- `HappAPNsScope.x` загружается только в `apsd`. Хук `nw_connection_create` копирует параметры APNs-соединения, снимает ограничение на физический интерфейс и требует текущий интерфейс VPN. Другие соединения сохраняют исходные параметры.

APNs определяется по TCP 5223; на TCP 443 дополнительно требуется имя `push.apple.com` или его поддомен. Номер utun и UUID не зашиты: интерфейс выбирается из SCDynamicStore при создании соединения. Если подходящий VPN отсутствует, их несколько или частный API недоступен, исходные параметры сохраняются. Маршрут `17.0.0.0/8` не добавляется. Полная блокировка физической сети выключена.

Установите `.deb` из Releases через менеджер пакетов RootHide. Требуются ElleKit, RootHide ≥ 0.1.0 и iOS ≥ 16.4. После установки перезапустите Happ и `apsd`, затем переподключите VPN. Для раздачи нужны отдельные HotspotVPN и HotspotVPN DNS из [соседнего проекта](https://github.com/shellovxx/HotSpotVPN).

Сборка использует [RootHide Theos](https://github.com/roothide/theos), SDK iOS 16.5 и совместимый с современным arm64e ABI Apple/Procursus clang:

```sh
make clean package FINALPACKAGE=1 DEBUG=0
# Альтернатива: clang, ld, lipo и ldid доступны в PATH
THEOS=/path/to/roothide-theos HAPP_SDK=/path/to/iPhoneOS16.5.sdk sh scripts/build-native.sh
```

Для ручной упаковки подписанных библиотек:

```sh
python3 scripts/package.py --binaries /path/to/binaries --output packages/local.happvpnpushroute_1.5.0_iphoneos-arm64e.deb
cc tests/endpoint_test.c -o /tmp/happ-endpoint-test && /tmp/happ-endpoint-test
```

Проверенная сборка использовала Procursus clang 16.0.0 и ld64 951.9. Упаковщик проверяет сигнатуры, PAC00 для системного `apsd`, загрузку Substrate через `.jbroot` и отсутствие старых путей `/var/jb/`. SDK, инструменты, пакеты и приватные данные исключены из Git.

В [проверке RootHide](verification-roothide.md) приведены фактические результаты. История предыдущей rootless-версии сохранена отдельно в [diagnosis-hotspot.md](diagnosis-hotspot.md). Доставка конкретного уведомления и специально вызванный fallback 443 отдельно не подтверждены.
