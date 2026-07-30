import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sorgun_emlak_defteri/main.dart';
import 'package:sorgun_emlak_defteri/models/customer.dart';
import 'package:sorgun_emlak_defteri/models/property_listing.dart';
import 'package:sorgun_emlak_defteri/screens/add_edit_listing_screen.dart';
import 'package:sorgun_emlak_defteri/services/address_repository.dart';
import 'package:sorgun_emlak_defteri/services/app_database.dart';
import 'package:sorgun_emlak_defteri/services/photo_service.dart';
import 'package:sorgun_emlak_defteri/services/platform_capabilities.dart';

void main() {
  late PlatformCapabilities previousCapabilities;

  setUp(() {
    previousCapabilities = PlatformCapabilitiesScope.current;
  });

  tearDown(() {
    PlatformCapabilitiesScope.current = previousCapabilities;
  });

  test('desktop capabilities keep phone-only actions disabled', () {
    const capabilities = PlatformCapabilities.desktop;
    expect(capabilities.isDesktop, isTrue);
    expect(capabilities.supportsCamera, isFalse);
    expect(capabilities.supportsContactPicker, isFalse);
    expect(capabilities.supportsLocationEditing, isFalse);
    expect(capabilities.supportsGallerySave, isFalse);
    expect(capabilities.supportsDirectCall, isFalse);
    expect(capabilities.supportsNativeShare, isFalse);
  });

  testWidgets('navigation adapts between mobile and desktop widths',
      (tester) async {
    final database = _FakeDatabase();
    final addressRepository = _FakeAddressRepository();

    await _setSurface(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: AppHome(
          database: database,
          addressRepository: addressRepository,
          photoService: PhotoService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mobile-app-layout')), findsOneWidget);
    expect(find.byKey(const Key('app-navigation-rail')), findsNothing);
    expect(tester.takeException(), isNull);

    await _setSurface(tester, const Size(1440, 900));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('desktop-app-layout')), findsOneWidget);
    expect(find.byKey(const Key('app-navigation-rail')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop draft only requires a property type', (tester) async {
    PlatformCapabilitiesScope.current = PlatformCapabilities.desktop;
    final database = _FakeDatabase();

    await _setSurface(tester, const Size(1100, 800));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AddEditListingScreen(
            database: database,
            addressRepository: _FakeAddressRepository(),
            photoService: PhotoService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Daire').first);
    await tester.pumpAndSettle();

    final formList = find.byType(ListView).first;
    for (var i = 0;
        i < 4 && find.text('İlanı kaydet').evaluate().isEmpty;
        i++) {
      await tester.drag(formList, const Offset(0, -650));
      await tester.pumpAndSettle();
    }
    expect(find.text('Kamera'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsWidgets);
    await tester.tap(find.text('İlanı kaydet'));
    await tester.pumpAndSettle();

    final listing = database.insertedListing;
    expect(listing, isNotNull);
    expect(listing!.placeName, isEmpty);
    expect(listing.dealType, isNull);
    expect(listing.costPrice, 0);
    expect(listing.salePrice, 0);
  });
}

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

class _FakeAddressRepository extends AddressRepository {
  @override
  Future<AddressBook> load() async {
    return const AddressBook(
      city: 'Yozgat',
      district: 'Sorgun',
      neighborhoods: ['Agahefendi'],
      villages: ['Arslanlı'],
      streets: ['Atatürk Caddesi'],
    );
  }
}

class _FakeDatabase extends AppDatabase {
  PropertyListing? insertedListing;

  @override
  Future<List<PropertyListing>> getActiveListings() async => const [];

  @override
  Future<Map<int, int>> getListingInterestCounts() async => const {};

  @override
  Future<List<Customer>> getCustomers() async => const [];

  @override
  Future<int> insertListing(PropertyListing listing) async {
    insertedListing = listing;
    return 1;
  }
}
