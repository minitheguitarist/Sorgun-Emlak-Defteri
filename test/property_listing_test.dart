import 'package:flutter_test/flutter_test.dart';
import 'package:sorgun_emlak_defteri/models/customer.dart';
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
      areaUnit: AreaUnit.squareMeter,
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
    expect(restored.areaUnit, AreaUnit.squareMeter);
    expect(restored.zoningStatus, 'Konut');
    expect(restored.roadFrontage, 'Var');
    expect(restored.deedStatus, 'Müstakil');
    expect(restored.utilities, 'Yakın');
  });

  test('arsa tarla alan birimi map icinde korunur', () {
    final now = DateTime(2026, 1, 1);
    final listing = PropertyListing(
      type: PropertyType.field,
      dealType: DealType.sale,
      placeKind: PlaceKind.village,
      placeName: 'Alisar Koyu',
      streetName: '',
      blockNo: '12',
      parcelNo: '8',
      squareMeters: AreaUnit.decare.toSquareMeters(5),
      areaUnit: AreaUnit.decare,
      costPrice: 2000,
      salePrice: 2500,
      description: '',
      photoPaths: const [],
      createdAt: now,
      updatedAt: now,
    );

    final restored = PropertyListing.fromMap(listing.toMap());

    expect(restored.squareMeters, 5000);
    expect(restored.areaUnit, AreaUnit.decare);
  });

  test('ilan silme ve satis musteri baglantisi map icinde korunur', () {
    final now = DateTime(2026, 1, 1);
    final deletedAt = DateTime(2026, 1, 2);
    final listing = PropertyListing(
      type: PropertyType.land,
      placeKind: PlaceKind.neighborhood,
      placeName: 'Yeni Mahallesi',
      streetName: '',
      blockNo: '12',
      parcelNo: '8',
      costPrice: 2000,
      salePrice: 2500,
      description: '',
      photoPaths: const [],
      isSold: true,
      soldPrice: 2400,
      soldAt: now,
      soldCustomerId: 7,
      isDeleted: true,
      deletedAt: deletedAt,
      createdAt: now,
      updatedAt: now,
    );

    final restored = PropertyListing.fromMap(listing.toMap());

    expect(restored.soldCustomerId, 7);
    expect(restored.isDeleted, isTrue);
    expect(restored.deletedAt, deletedAt);
  });

  test('musteri istek filtresi aktif ilanlari butceye gore eslestirir', () {
    final now = DateTime(2026, 1, 1);
    final filter = const CustomerRequestFilter(
      dealType: DealType.sale,
      type: PropertyType.apartment,
      roomLayout: '3+1',
      minSquareMeters: 120,
      maxSquareMeters: 160,
    );
    final matching = PropertyListing(
      type: PropertyType.apartment,
      dealType: DealType.sale,
      placeKind: PlaceKind.neighborhood,
      placeName: 'Yeni Mahallesi',
      streetName: 'Cumhuriyet Cadde',
      roomLayout: '3+1',
      squareMeters: 140,
      costPrice: 1000,
      salePrice: 2500,
      description: '',
      photoPaths: const [],
      createdAt: now,
      updatedAt: now,
    );
    final expensive = matching.copyWith(salePrice: 5000);
    final sold = matching.copyWith(isSold: true);

    expect(filter.matches(matching, minBudget: 2000, maxBudget: 3000), isTrue);
    expect(
        filter.matches(expensive, minBudget: 2000, maxBudget: 3000), isFalse);
    expect(filter.matches(sold, minBudget: 2000, maxBudget: 3000), isFalse);
  });

  test('musteri map icinde butce not ve istek filtresini korur', () {
    final now = DateTime(2026, 1, 1);
    final customer = Customer(
      fullName: 'Ali Veli',
      phone: '05551234567',
      minBudget: 1500,
      maxBudget: 3000,
      notes: 'Acele bakiyor',
      requestFilter: const CustomerRequestFilter(
        type: PropertyType.field,
        minSquareMeters: 5000,
        areaUnit: AreaUnit.decare,
      ),
      createdAt: now,
      updatedAt: now,
    );

    final restored = Customer.fromMap(customer.toMap());

    expect(restored.fullName, 'Ali Veli');
    expect(restored.phone, '05551234567');
    expect(restored.minBudget, 1500);
    expect(restored.maxBudget, 3000);
    expect(restored.notes, 'Acele bakiyor');
    expect(restored.requestFilter.type, PropertyType.field);
    expect(restored.requestFilter.minSquareMeters, 5000);
    expect(restored.requestFilter.areaUnit, AreaUnit.decare);
  });
}
