# Sorgun Emlak Defteri

Sorgun Emlak Defteri, Android icin hazirlanan cevrimdisi bir emlak takip uygulamasidir. Daire, arsa ve tarla kayitlari cihazda saklanir; fotoğraflar uygulamanin ozel klasorune kopyalanir; maliyet, satis fiyati, kar ve fiyat gecmisi emlakci tarafinda takip edilir.

## Ozellikler

- Hamburger menulu ana ekran: Listeleme, Ekleme, Duzenleme ve Satilanlar.
- Daire, arsa ve tarla icin ayri alanlar.
- Sorgun/Yozgat mahalle, koy ve cadde/sokak/yol seed verisi.
- Galeri ve kamera ile coklu fotograf ekleme.
- Maliyet, satis fiyati, kar ve kar yuzdesi hesabi.
- Aramali mahalle/koy ve cadde/sokak/yol secimi.
- Ilanlara haritadan konum secme, konumu acma ve konum paylasma.
- Uc telefon icin veritabani ve fotograflari tek dosyada disa/ice aktarma.
- Tek tikla acilip kapanan gizli bilgi paneli.
- Arsa ve tarla icin metrekare/donum secimli alan, imar, yola cephe, tapu ve elektrik/su bilgileri.
- WhatsApp/Instagram hikayesi icin galeriye kaydedilebilir reklam gorseli olusturma.
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

GitHub Actions workflow'u her push/pull request icin analiz, test ve release APK build adimlarini calistirir. Debug APK artifact olarak `sorgun-emlak-defteri-debug-apk` adiyla yuklenir. Tag release'lerinde imzali release APK ayrica `sorgun-emlak-defteri-release-apk` artifact'i ve GitHub Release asset'i olarak yayinlanir. GitHub Releases altinda yayinlanan APK'nin telefona kurulabilmesi icin release imzalama secret'lari tanimli olmalidir.

## Release Imzalama

GitHub'dan indirilen release APK'nin kurulabilmesi icin APK imzali olmalidir. Bir kere release keystore olusturun:

```bash
keytool -genkeypair -v \
  -keystore release-keystore.jks \
  -alias sorgun-emlak-defteri \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

Keystore'u base64'e cevirin:

```bash
base64 -w 0 release-keystore.jks
```

GitHub repo ayarlarinda `Settings > Secrets and variables > Actions` altina su secret'lari ekleyin:

- `ANDROID_KEYSTORE_BASE64`: base64 ciktisi
- `ANDROID_KEYSTORE_PASSWORD`: keystore sifresi
- `ANDROID_KEY_ALIAS`: `sorgun-emlak-defteri`
- `ANDROID_KEY_PASSWORD`: key sifresi

Bu keystore'u kaybetmeyin. Sonraki surumlerin mevcut uygulamanin ustune kurulabilmesi icin ayni keystore ile imzalanmasi gerekir.

Telefonda daha once `flutter run` veya debug APK ile kurulmus uygulama varsa, ilk imzali release APK onun ustune kurulamaz; debug ve release imzalari farklidir. Ilk release kurulumundan once eski debug uygulamasini kaldirin. Bu islem cihazdaki uygulama verisini siler.

GitHub Releases uzerinden indirilen yeni APK'nin eski surumun ustune kurulabilmesi icin uc kosul ayni anda saglanmalidir:

- Paket adi ayni kalmali: `com.sorgunemlak.defter`
- APK ayni release keystore ile imzalanmali
- `pubspec.yaml` icindeki build number artmali, ornek `1.0.3+4`

Tag release workflow'u bu build number'in onceki release'ten buyuk oldugunu kontrol eder.

## GitHub Release APK

Kullanıcıların APK'yi GitHub Releases sayfasindan indirmesi icin version tag'i gonderin:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Tag push edilince GitHub Actions release APK'yi derler ve `Releases` bolumune `sorgun-emlak-defteri-v1.0.0.apk` dosyasi olarak yukler.

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

Veritabanina yeni kolon eklendiginde `lib/services/app_database.dart` icinde veritabanı version'i artirilmali ve `onUpgrade` migration'i yazilmalidir. Bu projede oda tipi/metrekare alanlari version 2, konum koordinatlari version 3 migration'i ile eklenmistir.

## Adres Verisi

Uygulama `assets/data/sorgun_seed_data.json` dosyasini asset olarak paketler. Kaynak dosyalar `sorgunadresveritabanı/` klasorunde tutulur. Mevcut seed veri Sorgun icin mahalle/koy ve genel cadde/sokak/yol secenekleri verir; daha tam UAVT/MAKS verisi elde edilirse JSON ayni mantikla guncellenebilir.

## Lisans

Bu proje GNU General Public License v3.0 veya daha sonraki bir surum altinda lisanslanmistir: `GPL-3.0-or-later`.
