# 📱 OpenVK Legacy for iOS

Нативный легковесный клиент **OpenVK** для старых и современных устройств Apple (iOS 6.0 — iOS 18+, armv7 / armv7s / arm64).

---

## 🌌 Управление визуализацией MilkDrop 2

В аудиоплеере встроен аппаратный движок музыкальной визуализации Winamp **MilkDrop 2** (projectM OpenGL ES 2.0/3.0).

* **Свайп влево**: Следующий пресет.
* **Свайп вправо**: Предыдущий пресет.
* **Одиночный тап**: Случайный пресет (Shuffle).
* **Двойной тап**: Скрыть / показать FPS и название пресета.
* **Тап по области плеера**: Переключение между визуализатором и обложкой альбома.
* **Авто-смена**: Пресет автоматически переключается каждые 20 секунд во время музыки.

---

## 🛠 Сборка (Theos)

### С визуализатором MilkDrop 2:
```bash
make -j2 ipa FINALPACKAGE=1
```

### Без визуализации (быстрая сборка):
```bash
make -j2 ipa FINALPACKAGE=1 ENABLE_VISUALIZER=0
```

Итоговый `.ipa` будет создан в корне проекта: `OpenVK-Legacy.ipa`.

---

## 📄 Лицензия
GPL v3.0 • Powered by [OpenVK](https://github.com/openvk/openvk) & [projectM](https://github.com/projectM-visualizer/projectm).