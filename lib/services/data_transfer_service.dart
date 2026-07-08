import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

class DataTransferService {
  const DataTransferService({required AppDatabase database})
      : _database = database;

  final AppDatabase _database;

  Future<File> createPackage({String prefix = 'sorgun-emlak-defteri'}) async {
    final db = await _database.database;
    final listings = await db.query('listings', orderBy: 'id ASC');
    final history = await db.query('price_history', orderBy: 'id ASC');
    final archive = Archive();
    final exportListings = <Map<String, Object?>>[];
    var photoIndex = 0;

    for (final row in listings) {
      final exportRow = Map<String, Object?>.from(row);
      final paths = _decodePhotoList(exportRow['photos_json']);
      final packagedPaths = <String>[];

      for (final path in paths) {
        final file = File(path);
        if (!await file.exists()) {
          continue;
        }
        final bytes = await file.readAsBytes();
        final archiveName =
            'photos/${photoIndex}_${_safeFileName(p.basename(path))}';
        archive
            .addFile(ArchiveFile.noCompress(archiveName, bytes.length, bytes));
        packagedPaths.add(archiveName);
        photoIndex++;
      }

      exportRow['photos_json'] = jsonEncode(packagedPaths);
      exportListings.add(exportRow);
    }

    archive.addFile(
      ArchiveFile.string(
        'manifest.json',
        jsonEncode({
          'format': 'sorgun-emlak-defteri',
          'schemaVersion': 1,
          'databaseVersion': 4,
          'exportedAt': DateTime.now().toIso8601String(),
          'listingCount': exportListings.length,
          'photoCount': photoIndex,
        }),
      ),
    );
    archive.addFile(
      ArchiveFile.string(
        'data.json',
        jsonEncode({
          'listings': exportListings,
          'price_history': history,
        }),
      ),
    );

    final bytes = ZipEncoder().encode(archive);
    final directory = await getTemporaryDirectory();
    final file = File(
      p.join(directory.path, '$prefix-${_timestamp()}.sedef'),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<DataImportSummary> importPackage(String packagePath) async {
    final archive =
        ZipDecoder().decodeBytes(await File(packagePath).readAsBytes());
    final dataFile = archive.findFile('data.json');
    if (dataFile == null) {
      throw const FormatException('Veri paketi data.json içermiyor.');
    }

    final decoded = jsonDecode(utf8.decode(dataFile.content));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Veri paketi okunamadı.');
    }

    final rawListings = decoded['listings'];
    final rawHistory = decoded['price_history'];
    if (rawListings is! List || rawHistory is! List) {
      throw const FormatException('Veri paketi eksik.');
    }

    final backup = await createPackage(prefix: 'sorgun-emlak-yedek');
    final docs = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(docs.path, 'property_photos'));
    final importPhotosDir = Directory(
      p.join(docs.path,
          'property_photos_import_${DateTime.now().microsecondsSinceEpoch}'),
    );
    if (await importPhotosDir.exists()) {
      await importPhotosDir.delete(recursive: true);
    }
    await importPhotosDir.create(recursive: true);

    final importedListings = <Map<String, Object?>>[];
    var importedPhotoCount = 0;
    for (var i = 0; i < rawListings.length; i++) {
      final row = _dynamicMap(rawListings[i]);
      final packagePhotos = _decodePhotoList(row['photos_json']);
      final localPaths = <String>[];

      for (var photoPosition = 0;
          photoPosition < packagePhotos.length;
          photoPosition++) {
        final archiveName = packagePhotos[photoPosition];
        final photoFile = archive.findFile(archiveName);
        if (photoFile == null || !photoFile.isFile) {
          continue;
        }
        final fileName = _safeFileName(
          '${row['id'] ?? i}_${photoPosition}_${p.basename(archiveName)}',
        );
        final finalPath = p.join(photosDir.path, fileName);
        final tempPath = p.join(importPhotosDir.path, fileName);
        await File(tempPath).writeAsBytes(photoFile.content, flush: true);
        localPaths.add(finalPath);
        importedPhotoCount++;
      }

      row['photos_json'] = jsonEncode(localPaths);
      importedListings.add(_onlyColumns(row, _listingColumns));
    }

    final importedHistory = rawHistory
        .map(_dynamicMap)
        .map((row) => _onlyColumns(row, _historyColumns))
        .toList();

    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.delete('price_history');
      await txn.delete('listings');
      for (final row in importedListings) {
        await txn.insert('listings', row);
      }
      for (final row in importedHistory) {
        await txn.insert('price_history', row);
      }
    });

    if (await photosDir.exists()) {
      await photosDir.delete(recursive: true);
    }
    await importPhotosDir.rename(photosDir.path);

    return DataImportSummary(
      listingCount: importedListings.length,
      photoCount: importedPhotoCount,
      backupPath: backup.path,
    );
  }

  static List<String> _decodePhotoList(Object? value) {
    final decoded = value is String ? jsonDecode(value) : value;
    if (decoded is! List) {
      return const [];
    }
    return decoded.whereType<String>().toList();
  }

  static Map<String, Object?> _dynamicMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Veri paketi satırı okunamadı.');
    }
    return {
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }

  static Map<String, Object?> _onlyColumns(
    Map<String, Object?> row,
    Set<String> columns,
  ) {
    return {
      for (final entry in row.entries)
        if (columns.contains(entry.key)) entry.key: entry.value,
    };
  }

  static String _timestamp() {
    return DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
  }

  static String _safeFileName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'photo.jpg' : cleaned;
  }
}

class DataImportSummary {
  const DataImportSummary({
    required this.listingCount,
    required this.photoCount,
    required this.backupPath,
  });

  final int listingCount;
  final int photoCount;
  final String backupPath;
}

const _listingColumns = {
  'id',
  'type',
  'deal_type',
  'place_kind',
  'place_name',
  'street_name',
  'building_name',
  'block_no',
  'parcel_no',
  'room_layout',
  'square_meters',
  'building_age',
  'bathroom_count',
  'balcony_count',
  'housing_kind',
  'latitude',
  'longitude',
  'owner_name',
  'owner_phone',
  'cost_price',
  'sale_price',
  'description',
  'photos_json',
  'is_sold',
  'sold_price',
  'sold_at',
  'created_at',
  'updated_at',
};

const _historyColumns = {
  'id',
  'listing_id',
  'old_price',
  'new_price',
  'changed_at',
};
