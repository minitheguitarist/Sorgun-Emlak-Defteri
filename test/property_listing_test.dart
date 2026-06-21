import 'package:flutter_test/flutter_test.dart';
import 'package:sorgun_emlak_defteri/models/property_listing.dart';
import 'package:sorgun_emlak_defteri/models/property_type.dart';
import 'package:sorgun_emlak_defteri/services/formatters.dart';

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
}
