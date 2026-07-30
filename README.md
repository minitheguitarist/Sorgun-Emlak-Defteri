# Sorgun Emlak Defteri

Sorgun Emlak Defteri; Android, Linux ve Windows icin cevrimdisi bir emlak takip uygulamasidir. Daire, arsa ve tarla kayitlari cihazda saklanir; fotograflar uygulamanin ozel klasorune kopyalanir; maliyet, satis fiyati, kar ve fiyat gecmisi emlakci tarafinda takip edilir.

## Ozellikler

- Telefonda hamburger menusu, genis masaustu pencerelerinde kalici yan gezinme cubugu.
- Genis ekranda iki sutunlu ilan kartlari ve okunabilirligi koruyan sinirli icerik genisligi.
- Daire, arsa ve tarla icin ayri alanlar.
- Sorgun/Yozgat mahalle, koy ve cadde/sokak/yol seed verisi.
- Galeri ve kamera ile coklu fotograf ekleme.
- Maliyet, satis fiyati, kar ve kar yuzdesi hesabi.
- Aramali mahalle/koy ve cadde/sokak/yol secimi.
- Ilanlara haritadan konum secme, konumu acma ve konum paylasma.
- Uc telefon icin ilanlari, musterileri, baglantilari ve fotograflari tek dosyada disa/ice aktarma.
- Tek tikla acilip kapanan gizli bilgi paneli.
- Arsa ve tarla icin metrekare/donum secimli alan, imar, yola cephe, tapu ve elektrik/su bilgileri.
- WhatsApp/Instagram hikayesi icin galeriye kaydedilebilir reklam gorseli olusturma.
- Musteri kaydi, rehberden kisi secme, butce/istek filtresi, arama ve WhatsApp kisayollari.
- Ilanlara ilgilenen musteri baglama ve satista opsiyonel alici musteri secme.
- Duzenleme ekranindan ilan silme, silineni geri alma ve satilan ilani tekrar aktif yapma.
- Fiyat degisikliklerinde otomatik fiyat gecmisi.
- Satildi akisi: gercek satis fiyati girilir, ilan aktif listeden cikar ve Satilanlar arsivine duser.
- GitHub Actions ile release APK artifact uretimi.
- GitHub Actions ile Fedora 44 x86_64 RPM ve Windows x64 kurulum EXE'si uretimi.

## Masaustu Davranisi

Linux ve Windows surumleri mobil veri modelini ve `.sedef` aktarim paketini kullanir. Masaustunde yeni bir taslak kaydetmek icin yalnizca mulk tipi zorunludur; bos sayisal alanlar `0`, secilmemis alanlar bos olarak saklanir. Bu taslak Android v1.0.7'ye aktarilip telefonda tamamlanabilir.

Rehberden kisi secme, kamera, mevcut konumdan adres bulma, telefonla arama, konum paylasma ve reklam gorselini telefon galerisine kaydetme gibi telefona bagli islemler masaustunde kilit simgesiyle gosterilir. Kilit uzerinde bekletildiginde aciklama gorunur. Dosyadan fotograf secme, `.sedef` ice/disa aktarma, haritada kayitli konumu acma ve WhatsApp baglantilari masaustunde kullanilabilir.

## Gelistirme

Flutter kurulu bir makinede:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d android
flutter run -d linux
flutter run -d windows
```

Yerel release build'leri:

```bash
flutter build apk --release
flutter build linux --release
flutter build windows --release
```

Fedora 44'te yerel RPM:

```bash
flutter build linux --release
./scripts/build-rpm.sh
```

RPM `build/rpmbuild/RPMS/x86_64/` altinda olusur. Flutter uygulamasi native kod icerdigi icin paket `noarch` degil, `x86_64` olarak uretilir.

GitHub Actions workflow'lari her push/pull request icin analiz ve test calistirir. Android workflow'u APK, Desktop Builds workflow'u Fedora 44 x86_64 RPM ile Windows x64 kurulum EXE'si uretir. Bir tag calismasinda veya `release_tag` girilerek elle baslatildiginda masaustu dosyalari ve SHA-256 dosyalari ilgili GitHub Release'e eklenir.

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
