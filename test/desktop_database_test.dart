import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sorgun_emlak_defteri/models/property_listing.dart';
import 'package:sorgun_emlak_defteri/models/property_type.dart';
import 'package:sorgun_emlak_defteri/services/app_database.dart';

void main() {
  test('desktop FFI database stores Android-compatible draft records',
      () async {
    final directory = await Directory.systemTemp.createTemp('sedef-db-test-');
    addTearDown(() => directory.delete(recursive: true));
    final database = AppDatabase(
      databasePath: p.join(directory.path, 'sorgun_emlak_defteri.db'),
    );
    final now = DateTime(2026, 7, 30);

    final id = await database.insertListing(
      PropertyListing(
        type: PropertyType.land,
        placeKind: PlaceKind.neighborhood,
        placeName: '',
        streetName: '',
        costPrice: 0,
        salePrice: 0,
        description: '',
        photoPaths: const [],
        createdAt: now,
        updatedAt: now,
      ),
    );

    final stored = await database.getListing(id);
    expect(stored, isNotNull);
    expect(stored!.type, PropertyType.land);
    expect(stored.dealType, isNull);
    expect(stored.placeName, isEmpty);
    expect(stored.costPrice, 0);
    expect(stored.salePrice, 0);
  });
}
