# OpenVK Legacy (iOS 5.0 – 10.x, 32-bit & 64-bit)

Этот проект — переписанный и адаптированный клиент **OpenVK** для старых версий iOS (iOS 5, 6, 7, 8, 9, 10), поддерживающий архитектуры **armv7 (32-bit)**, **armv7s** и **arm64**.

---

## 📌 Почему оригинальный репозиторий (Swift / SwiftUI) нельзя запустить на старых iOS напрямую?
1. **SwiftUI** появился только в **iOS 13.0** (2019 год) и принципиально не работает на iOS 5–12.
2. **Swift** не поддерживался на ранних iOS (iOS 5–6), а стабильный стабильный ABI появился только в iOS 12.2.
3. Для 32-битных устройств (iPhone 4, 4S, 5, 5C, iPad 1/2/3/4/mini 1, iPod Touch 4/5) стандартом де-факто является **Objective-C + UIKit**.
4. Весь оригинальный функционал API OpenVK (токены, методы `newsfeed.get`, `messages.*`, `wall.*`, `users.get`, выбор серверов) сохранен и перенесен в чистый Objective-C код.

---

## 🛠 Сборка через Theos в WSL (Windows Subsystem for Linux)

Вам **не нужен Mac** — Theos в WSL под Linux (Ubuntu/Debian) полностью поддерживает кросс-компиляцию под iOS.

### 1. Переход в папку проекта в WSL:
Путь к проекту с диска `D:` в WSL:
```bash
cd "/mnt/d/странные проекты/OpenVK-iOS-Legacy"
```

### 2. Установка Theos (если еще не установлен):
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"
```
Добавьте в `~/.bashrc`:
```bash
export THEOS=~/theos
export PATH=$THEOS/bin:$PATH
```

### 3. Установка iOS SDK в Theos:
Скачайте `iPhoneOS9.3.sdk` или `iPhoneOS11.2.sdk` / `iPhoneOS14.5.sdk` в папку `$THEOS/sdks`:
```bash
git clone https://github.com/theos/sdks.git $THEOS/sdks
```

### 4. Сборка пакета (.deb):
```bash
make clean
make package FINALPACKAGE=1
```
Готовый `.deb` появится в папке `packages/`. Его можно установить через Cydia / Sileo / Zebra / Filza / dpkg на устройство с джейлбрейком.

### 5. Сборка в .IPA (для установки без джейлбрейка или через sideload):
После команды `make` папка приложения будет лежать в `.theos/obj/debug/OpenVK.app` (или `.theos/obj/OpenVK.app`):
```bash
mkdir Payload
cp -r .theos/obj/debug/OpenVK.app Payload/
zip -r OpenVK-Legacy.ipa Payload
rm -rf Payload
```

---

## 📁 Структура папок:
- `OpenVK-iOS-original` — исходный репозиторий с GitHub.
- `OpenVK-iOS-Backup` — неизмененная резервная копия.
- `OpenVK-iOS-Legacy` — форк для Theos / старых iOS (32/64 bit).
