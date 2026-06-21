import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/property_type.dart';

class AddressBook {
  const AddressBook({
    required this.city,
    required this.district,
    required this.neighborhoods,
    required this.villages,
    required this.streets,
  });

  final String city;
  final String district;
  final List<String> neighborhoods;
  final List<String> villages;
  final List<String> streets;

  List<String> placesFor(PlaceKind kind) {
    return kind == PlaceKind.neighborhood ? neighborhoods : villages;
  }
}

class AddressRepository {
  AddressBook? _cached;

  Future<AddressBook> load() async {
    if (_cached != null) {
      return _cached!;
    }

    final raw =
        await rootBundle.loadString('assets/data/sorgun_seed_data.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;

    final neighborhoods = _uniqueSorted([
      ..._stringList(data['sorgun_merkez_mahalleleri_seed']),
      ..._stringList(data['tum_mahalleler_flat_seed']),
    ]);

    final villages = _uniqueSorted(_stringList(data['koyler_seed']));
    final streets = _uniqueSorted([
      ..._streetList(data['sorgun_geneli_osm_cadde_sokak_yol_seed']),
      ..._streetList(data['agahefendi_mahallesi_gorunen_ilk_15_sokak_seed']),
    ]);

    _cached = AddressBook(
      city: data['il'] as String? ?? 'Yozgat',
      district: data['ilce'] as String? ?? 'Sorgun',
      neighborhoods: neighborhoods,
      villages: villages,
      streets: streets,
    );
    return _cached!;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value.whereType<String>().toList();
  }

  static List<String> _streetList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final name = (item['ad'] as String? ?? '').trim();
          final type = (item['tip'] as String? ?? '').trim();
          if (name.isEmpty) {
            return type;
          }
          if (type.isEmpty) {
            return name;
          }
          return '$name $type';
        })
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  static List<String> _uniqueSorted(Iterable<String> values) {
    final normalized = <String, String>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      normalized.putIfAbsent(trimmed.toLowerCase(), () => trimmed);
    }

    final list = normalized.values.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }
}
