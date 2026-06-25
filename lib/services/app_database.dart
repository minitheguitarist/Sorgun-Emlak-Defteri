import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/price_history.dart';
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
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE listings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL,
  place_kind TEXT NOT NULL,
  place_name TEXT NOT NULL,
  street_name TEXT NOT NULL,
  building_name TEXT,
  block_no TEXT,
  parcel_no TEXT,
  room_layout TEXT,
  square_meters REAL,
  latitude REAL,
  longitude REAL,
  cost_price REAL NOT NULL,
  sale_price REAL NOT NULL,
  description TEXT NOT NULL,
  photos_json TEXT NOT NULL,
  is_sold INTEGER NOT NULL DEFAULT 0,
  sold_price REAL,
  sold_at TEXT,
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
          'CREATE INDEX idx_history_listing ON price_history(listing_id)',
        );
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
      },
    );
    return _database!;
  }

  Future<List<PropertyListing>> getActiveListings() {
    return _getListings(where: 'is_sold = 0');
  }

  Future<List<PropertyListing>> getSoldListings() {
    return _getListings(where: 'is_sold = 1');
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
  }) async {
    final db = await database;
    final now = DateTime.now();
    await db.update(
      'listings',
      {
        'is_sold': 1,
        'sold_price': soldPrice,
        'sold_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
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
}
