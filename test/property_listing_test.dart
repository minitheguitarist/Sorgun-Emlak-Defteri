import 'package:flutter_test/flutter_test.dart';
import 'package:sorgun_emlak_defteri/models/property_listing.dart';
import 'package:sorgun_emlak_defteri/models/property_type.dart';
import 'package:sorgun_emlak_defteri/services/formatters.dart';
import 'package:sorgun_emlak_defteri/services/location_links.dart';

void main() {
  test('kar marji guncel satis fiyatindan hesaplanir', () {
    final now = DateTime(2026, 1, 1);
    final listing = PropertyListing(
      type: PropertyType.apartment,
      placeKind: PlaceKind.neighborhood,
      placeName: 'Yeni Mahallesi',
      streetName: 'Cumhuriyet Cadde',
      buildingName: 'Merkez Apartmani',
      costPrice: 2000,
      salePrice: 2500,
      description: '',
      photoPaths: const [],
      createdAt: now,
      updatedAt: now,
    );

    expect(listing.activeProfit, 500);
    expect(listing.activeProfitPercent, 20);
  });

  test('satilan ilanda nihai kar gercek satis fiyatindan hesaplanir', () {
    final now = DateTime(2026, 1, 1);
    final listing = PropertyListing(
      type: PropertyType.land,
      placeKind: PlaceKind.village,
      placeName: 'Alisar Koyu',
      streetName: 'Alisar Yol',
      blockNo: '12',
      parcelNo: '8',
      costPrice: 2000,
      salePrice: 2500,
      description: '',
      photoPaths: const [],
      isSold: true,
      soldPrice: 2100,
      soldAt: now,
      createdAt: now,
      updatedAt: now,
    );

    expect(listing.finalPrice, 2100);
    expect(listing.finalProfit, 100);
    expect(listing.finalProfitPercent, closeTo(4.76, 0.01));
  });

  test('para girdisi turkce bicimleri kabul eder', () {
    expect(parseMoneyInput('1.250.000 TL'), 1250000);
    expect(parseMoneyInput('1250,50'), 1250.5);
  });

  test('arsa ve tarlada baslik aciklamanin ilk satirindan gelir', () {
    final now = DateTime(2026, 1, 1);
    final listing = PropertyListing(
      type: PropertyType.field,
      placeKind: PlaceKind.village,
      placeName: 'Alisar Koyu',
      streetName: '',
      blockNo: '12',
      parcelNo: '8',
      costPrice: 2000,
      salePrice: 2500,
      description: 'Yola yakin tarla\nDetay notu',
      photoPaths: const [],
      createdAt: now,
      updatedAt: now,
    );

    expect(listing.displayTitle, 'Yola yakin tarla');
    expect(listing.parcelLine, 'Ada 12 / Parsel 8');
  });

  test('metrekare girdisi nokta ve virgul ondalik kabul eder', () {
    expect(parseOptionalNumberInput('120.5'), 120.5);
    expect(parseOptionalNumberInput('120,5'), 120.5);
  });

  test('konum bilgisi kayit modelinde ve maps linkinde korunur', () {
    final now = DateTime(2026, 1, 1);
    final listing = PropertyListing(
      type: PropertyType.land,
      placeKind: PlaceKind.neighborhood,
      placeName: 'Yeni Mahallesi',
      streetName: 'Cumhuriyet Cadde',
      blockNo: '12',
      parcelNo: '8',
      latitude: 39.8104,
      longitude: 35.185,
      costPrice: 2000,
      salePrice: 2500,
      description: '',
      photoPaths: const [],
      createdAt: now,
      updatedAt: now,
    );

    final restored = PropertyListing.fromMap(listing.toMap());
    final uri = googleMapsUri(
      latitude: restored.latitude!,
      longitude: restored.longitude!,
    );

    expect(restored.hasLocation, isTrue);
    expect(restored.latitude, 39.8104);
    expect(restored.longitude, 35.185);
    expect(uri.toString(), contains('query=39.8104%2C35.185'));
  });

  test('yeni ilan detay alanlari map icinde korunur', () {
    final now = DateTime(2026, 1, 1);
    final listing = PropertyListing(
      type: PropertyType.apartment,
      dealType: DealType.rent,
      placeKind: PlaceKind.neighborhood,
      placeName: 'Aydinlikevler Mahallesi',
      streetName: 'Cumhuriyet Cadde',
      buildingName: 'Merkez Apartmani',
      roomLayout: '3+1',
      squareMeters: 145,
      buildingAge: 8,
      bathroomCount: 2,
      balconyCount: 1,
      housingKind: HousingKind.site,
      floorCount: 12,
      floorNumber: 5,
      frontage: 'Güney Cephe',
      ownerName: 'Ali Veli',
      ownerPhone: '05551234567',
      ownerPhones: const ['05551234567', '05557654321'],
      costPrice: 2000,
      salePrice: 15000,
      description: '',
      photoPaths: const [],
      createdAt: now,
      updatedAt: now,
    );

    final restored = PropertyListing.fromMap(listing.toMap());

    expect(restored.dealType, DealType.rent);
    expect(restored.buildingAge, 8);
    expect(restored.bathroomCount, 2);
    expect(restored.balconyCount, 1);
    expect(restored.housingKind, HousingKind.site);
    expect(restored.floorCount, 12);
    expect(restored.floorNumber, 5);
    expect(restored.frontage, 'Güney Cephe');
    expect(restored.ownerName, 'Ali Veli');
    expect(restored.ownerPhone, '05551234567');
    expect(restored.ownerPhoneList, ['05551234567', '05557654321']);
  });

  test('arsa tarla reklam alanlari map icinde korunur', () {
    final now = DateTime(2026, 1, 1);
    final listing = PropertyListing(
      type: PropertyType.land,
      dealType: DealType.sale,
      placeKind: PlaceKind.neighborhood,
      placeName: 'Yeni Mahallesi',
      streetName: '',
      blockNo: '123',
      parcelNo: '45',
      squareMeters: 2450,
      zoningStatus: 'Konut',
      roadFrontage: 'Var',
      deedStatus: 'Müstakil',
      utilities: 'Yakın',
      costPrice: 2000,
      salePrice: 2500,
      description: '',
      photoPaths: const [],
      createdAt: now,
      updatedAt: now,
    );

    final restored = PropertyListing.fromMap(listing.toMap());

    expect(restored.squareMeters, 2450);
    expect(restored.zoningStatus, 'Konut');
    expect(restored.roadFrontage, 'Var');
    expect(restored.deedStatus, 'Müstakil');
    expect(restored.utilities, 'Yakın');
  });
}
