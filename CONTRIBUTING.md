# Katki Rehberi

Bu proje Flutter ile gelistirilen Android odakli bir emlak takip uygulamasidir.

## Yerel Kontrol

Degisiklik gondermeden once:

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

## Veri Tabani Degisiklikleri

`listings` veya `price_history` semasi degistiginde:

- `lib/services/app_database.dart` icindeki database `version` degeri artirilmali.
- Eski kullanici verisini korumak icin `onUpgrade` migration'i yazilmali.
- Model testleri guncellenmeli.

## Lisans

Katkilar `GPL-3.0-or-later` lisansi altinda kabul edilir.
