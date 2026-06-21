# Sorgun Emlak Defteri

Sorgun Emlak Defteri, Android icin hazirlanan cevrimdisi bir emlak takip uygulamasidir. Daire, arsa ve tarla kayitlari cihazda saklanir; fotoğraflar uygulamanin ozel klasorune kopyalanir; maliyet, satis fiyati, kar ve fiyat gecmisi emlakci tarafinda takip edilir.

## Ozellikler

- Hamburger menulu ana ekran: Listeleme, Ekleme, Duzenleme ve Satilanlar.
- Daire, arsa ve tarla icin ayri alanlar.
- Sorgun/Yozgat mahalle, koy ve cadde/sokak/yol seed verisi.
- Galeri ve kamera ile coklu fotograf ekleme.
- Maliyet, satis fiyati, kar ve kar yuzdesi hesabi.
- Tek tikla acilip kapanan gizli bilgi paneli.
- Fiyat degisikliklerinde otomatik fiyat gecmisi.
- Satildi akisi: gercek satis fiyati girilir, ilan aktif listeden cikar ve Satilanlar arsivine duser.
- GitHub Actions ile release APK artifact uretimi.

## Gelistirme

Flutter kurulu bir makinede:

```bash
flutter create --platforms android --org com.sorgunemlak --project-name sorgun_emlak_defteri .
flutter pub get
flutter analyze
flutter test
flutter run
```

Release APK:

```bash
flutter build apk --release
```

GitHub Actions workflow'u her push/pull request icin analiz, test ve release APK build adimlarini calistirir. Uretilen dosya artifact olarak `sorgun-emlak-defteri-apk` adiyla yuklenir.

## Uygulamayi Guncelleme

Yeni ozellik ekledikten sonra ayni paket adi (`com.sorgunemlak.defter`) ile APK kuruldugunda telefondaki veriler korunur.

```bash
flutter analyze
flutter test
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Yayin/arsiv icin `pubspec.yaml` icindeki `version` degerini artirip release APK alin:

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Veritabanina yeni kolon eklendiginde `lib/services/app_database.dart` icinde veritabanı version'i artirilmali ve `onUpgrade` migration'i yazilmalidir. Bu projede oda tipi ve metrekare alanlari version 2 migration'i ile eklenmistir.

## Adres Verisi

Uygulama `assets/data/sorgun_seed_data.json` dosyasini asset olarak paketler. Kaynak dosyalar `sorgunadresveritabanı/` klasorunde tutulur. Mevcut seed veri Sorgun icin mahalle/koy ve genel cadde/sokak/yol secenekleri verir; daha tam UAVT/MAKS verisi elde edilirse JSON ayni mantikla guncellenebilir.

## Lisans

Bu proje GNU General Public License v3.0 veya daha sonraki bir surum altinda lisanslanmistir: `GPL-3.0-or-later`.
