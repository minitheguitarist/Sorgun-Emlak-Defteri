import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/customer.dart';
import '../models/price_history.dart';
import '../models/app_settings.dart';
import '../models/property_listing.dart';

class AppDatabase {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final basePath = await getDatabasesPath();
    final dbPath = p.join(basePath, 'sorgun_emlak_defteri.db');
    _database = await openDatabase(
      dbPath,
      version: 8,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE listings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL,
  deal_type TEXT,
  place_kind TEXT NOT NULL,
  place_name TEXT NOT NULL,
  street_name TEXT NOT NULL,
  building_name TEXT,
  block_no TEXT,
  parcel_no TEXT,
  room_layout TEXT,
  square_meters REAL,
  area_unit TEXT,
  building_age INTEGER,
  bathroom_count INTEGER,
  balcony_count INTEGER,
  housing_kind TEXT,
  floor_count INTEGER,
  floor_number INTEGER,
  frontage TEXT,
  zoning_status TEXT,
  road_frontage TEXT,
  deed_status TEXT,
  utilities TEXT,
  latitude REAL,
  longitude REAL,
  owner_name TEXT,
  owner_phone TEXT,
  owner_phones_json TEXT,
  cost_price REAL NOT NULL,
  sale_price REAL NOT NULL,
  description TEXT NOT NULL,
  photos_json TEXT NOT NULL,
  is_sold INTEGER NOT NULL DEFAULT 0,
  sold_price REAL,
  sold_at TEXT,
  sold_customer_id INTEGER,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  deleted_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
        await db.execute('''
CREATE TABLE price_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  listing_id INTEGER NOT NULL,
  old_price REAL NOT NULL,
  new_price REAL NOT NULL,
  changed_at TEXT NOT NULL,
  FOREIGN KEY(listing_id) REFERENCES listings(id) ON DELETE CASCADE
)
''');
        await db.execute(
          'CREATE INDEX idx_listings_status_type ON listings(is_sold, type)',
        );
        await db.execute(
          'CREATE INDEX idx_listings_deleted ON listings(is_deleted)',
        );
        await db.execute(
          'CREATE INDEX idx_history_listing ON price_history(listing_id)',
        );
        await _createSettingsTable(db);
        await _createCustomerTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE listings ADD COLUMN room_layout TEXT');
          await db.execute(
            'ALTER TABLE listings ADD COLUMN square_meters REAL',
          );
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE listings ADD COLUMN latitude REAL');
          await db.execute('ALTER TABLE listings ADD COLUMN longitude REAL');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE listings ADD COLUMN deal_type TEXT');
          await db.execute(
            'ALTER TABLE listings ADD COLUMN building_age INTEGER',
          );
          await db.execute(
            'ALTER TABLE listings ADD COLUMN bathroom_count INTEGER',
          );
          await db.execute(
            'ALTER TABLE listings ADD COLUMN balcony_count INTEGER',
          );
          await db.execute('ALTER TABLE listings ADD COLUMN housing_kind TEXT');
          await db.execute('ALTER TABLE listings ADD COLUMN owner_name TEXT');
          await db.execute('ALTER TABLE listings ADD COLUMN owner_phone TEXT');
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE listings ADD COLUMN floor_count INTEGER',
          );
          await db.execute(
            'ALTER TABLE listings ADD COLUMN floor_number INTEGER',
          );
          await db.execute('ALTER TABLE listings ADD COLUMN frontage TEXT');
          await db.execute(
            'ALTER TABLE listings ADD COLUMN owner_phones_json TEXT',
          );
        }
        if (oldVersion < 6) {
          await db.execute(
            'ALTER TABLE listings ADD COLUMN zoning_status TEXT',
          );
          await db.execute(
            'ALTER TABLE listings ADD COLUMN road_frontage TEXT',
          );
          await db.execute('ALTER TABLE listings ADD COLUMN deed_status TEXT');
          await db.execute('ALTER TABLE listings ADD COLUMN utilities TEXT');
          await _createSettingsTable(db);
        }
        if (oldVersion < 7) {
          await db.execute('ALTER TABLE listings ADD COLUMN area_unit TEXT');
        }
        if (oldVersion < 8) {
          await db.execute(
            'ALTER TABLE listings ADD COLUMN sold_customer_id INTEGER',
          );
          await db.execute(
            'ALTER TABLE listings ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute('ALTER TABLE listings ADD COLUMN deleted_at TEXT');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_listings_deleted ON listings(is_deleted)',
          );
          await _createCustomerTables(db);
        }
      },
    );
    return _database!;
  }

  static Future<void> _createSettingsTable(DatabaseExecutor db) {
    return db.execute('''
CREATE TABLE IF NOT EXISTS app_settings (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  agency_name TEXT NOT NULL DEFAULT '',
  agent_name TEXT NOT NULL DEFAULT '',
  agent_phone TEXT NOT NULL DEFAULT '',
  updated_at TEXT NOT NULL
)
''');
  }

  static Future<void> _createCustomerTables(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS customers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  full_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  min_budget REAL,
  max_budget REAL,
  notes TEXT NOT NULL DEFAULT '',
  request_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS listing_interests (
  listing_id INTEGER NOT NULL,
  customer_id INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY(listing_id, customer_id)
)
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(full_name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_interests_customer ON listing_interests(customer_id)',
    );
  }

  Future<AppSettings> getAppSettings() async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) {
      return const AppSettings();
    }
    return AppSettings.fromMap(rows.first);
  }

  Future<void> saveAppSettings(AppSettings settings) async {
    final db = await database;
    await db.insert(
      'app_settings',
      settings.copyWith(updatedAt: DateTime.now()).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PropertyListing>> getActiveListings() {
    return _getListings(where: 'is_sold = 0 AND is_deleted = 0');
  }

  Future<List<PropertyListing>> getSoldListings() {
    return _getListings(where: 'is_sold = 1 AND is_deleted = 0');
  }

  Future<List<PropertyListing>> getDeletedListings() {
    return _getListings(where: 'is_deleted = 1');
  }

  Future<List<PropertyListing>> _getListings({required String where}) async {
    final db = await database;
    final rows = await db.query(
      'listings',
      where: where,
      orderBy: 'updated_at DESC',
    );
    return rows.map(PropertyListing.fromMap).toList();
  }

  Future<PropertyListing?> getListing(int id) async {
    final db = await database;
    final rows = await db.query(
      'listings',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return PropertyListing.fromMap(rows.first);
  }

  Future<int> insertListing(PropertyListing listing) async {
    final db = await database;
    final now = DateTime.now();
    final item = listing.copyWith(createdAt: now, updatedAt: now);
    return db.insert('listings', item.toMap());
  }

  Future<void> updateListing(PropertyListing listing) async {
    final id = listing.id;
    if (id == null) {
      throw ArgumentError('Listing id is required for update.');
    }

    final db = await database;
    await db.transaction((txn) async {
      final previousRows = await txn.query(
        'listings',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (previousRows.isEmpty) {
        return;
      }

      final previous = PropertyListing.fromMap(previousRows.first);
      final updated = listing.copyWith(updatedAt: DateTime.now());
      await txn.update(
        'listings',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );

      if ((previous.salePrice - updated.salePrice).abs() >= 0.01) {
        await txn.insert(
          'price_history',
          PriceHistory(
            listingId: id,
            oldPrice: previous.salePrice,
            newPrice: updated.salePrice,
            changedAt: DateTime.now(),
          ).toMap(),
        );
      }
    });
  }

  Future<void> markSold({
    required int listingId,
    required double soldPrice,
    int? soldCustomerId,
  }) async {
    final db = await database;
    final now = DateTime.now();
    await db.update(
      'listings',
      {
        'is_sold': 1,
        'sold_price': soldPrice,
        'sold_at': now.toIso8601String(),
        'sold_customer_id': soldCustomerId,
        'is_deleted': 0,
        'deleted_at': null,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [listingId],
    );
  }

  Future<void> reactivateListing(int listingId) async {
    final db = await database;
    await db.update(
      'listings',
      {
        'is_sold': 0,
        'sold_price': null,
        'sold_at': null,
        'sold_customer_id': null,
        'is_deleted': 0,
        'deleted_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [listingId],
    );
  }

  Future<void> softDeleteListing(int listingId) async {
    final db = await database;
    final now = DateTime.now();
    await db.update(
      'listings',
      {
        'is_deleted': 1,
        'deleted_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [listingId],
    );
  }

  Future<void> restoreListing(int listingId) async {
    final db = await database;
    await db.update(
      'listings',
      {
        'is_deleted': 0,
        'deleted_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [listingId],
    );
  }

  Future<List<PriceHistory>> getPriceHistory(int listingId) async {
    final db = await database;
    final rows = await db.query(
      'price_history',
      where: 'listing_id = ?',
      whereArgs: [listingId],
      orderBy: 'changed_at DESC',
    );
    return rows.map(PriceHistory.fromMap).toList();
  }

  Future<List<Customer>> getCustomers() async {
    final db = await database;
    final rows = await db.query(
      'customers',
      orderBy: 'full_name COLLATE NOCASE ASC',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer?> getCustomer(int id) async {
    final db = await database;
    final rows = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Customer.fromMap(rows.first);
  }

  Future<int> insertCustomer(Customer customer) async {
    final db = await database;
    final now = DateTime.now();
    return db.insert(
      'customers',
      customer.copyWith(createdAt: now, updatedAt: now).toMap(),
    );
  }

  Future<void> updateCustomer(Customer customer) async {
    final id = customer.id;
    if (id == null) {
      throw ArgumentError('Customer id is required for update.');
    }
    final db = await database;
    await db.update(
      'customers',
      customer.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteCustomer(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'listing_interests',
        where: 'customer_id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'listings',
        {'sold_customer_id': null},
        where: 'sold_customer_id = ?',
        whereArgs: [id],
      );
      await txn.delete('customers', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<Customer>> getInterestedCustomers(int listingId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
SELECT c.*
FROM customers c
INNER JOIN listing_interests i ON i.customer_id = c.id
WHERE i.listing_id = ?
ORDER BY c.full_name COLLATE NOCASE ASC
''',
      [listingId],
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<List<int>> getInterestedCustomerIds(int listingId) async {
    final db = await database;
    final rows = await db.query(
      'listing_interests',
      columns: ['customer_id'],
      where: 'listing_id = ?',
      whereArgs: [listingId],
      orderBy: 'created_at ASC',
    );
    return rows
        .map((row) => (row['customer_id'] as num?)?.toInt())
        .whereType<int>()
        .toList();
  }

  Future<Map<int, int>> getListingInterestCounts() async {
    final db = await database;
    final rows = await db.rawQuery('''
SELECT listing_id, COUNT(*) AS count
FROM listing_interests
GROUP BY listing_id
''');
    return {
      for (final row in rows)
        (row['listing_id'] as num).toInt(): (row['count'] as num).toInt(),
    };
  }

  Future<void> setListingInterests({
    required int listingId,
    required Set<int> customerIds,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete(
        'listing_interests',
        where: 'listing_id = ?',
        whereArgs: [listingId],
      );
      for (final customerId in customerIds) {
        await txn.insert('listing_interests', {
          'listing_id': listingId,
          'customer_id': customerId,
          'created_at': now,
        });
      }
    });
  }

  Future<List<PropertyListing>> getSoldListingsForCustomer(int customerId) {
    return _getListings(
      where:
          'is_sold = 1 AND is_deleted = 0 AND sold_customer_id = $customerId',
    );
  }
}
