import 'dart:convert';

import 'property_listing.dart';
import 'property_type.dart';

class Customer {
  const Customer({
    this.id,
    required this.fullName,
    required this.phone,
    this.minBudget,
    this.maxBudget,
    this.notes = '',
    this.requestFilter = const CustomerRequestFilter(),
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String fullName;
  final String phone;
  final double? minBudget;
  final double? maxBudget;
  final String notes;
  final CustomerRequestFilter requestFilter;
  final DateTime createdAt;
  final DateTime updatedAt;

  Customer copyWith({
    int? id,
    String? fullName,
    String? phone,
    double? minBudget,
    double? maxBudget,
    String? notes,
    CustomerRequestFilter? requestFilter,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      minBudget: minBudget ?? this.minBudget,
      maxBudget: maxBudget ?? this.maxBudget,
      notes: notes ?? this.notes,
      requestFilter: requestFilter ?? this.requestFilter,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      'min_budget': minBudget,
      'max_budget': maxBudget,
      'notes': notes.trim(),
      'request_json': jsonEncode(requestFilter.toMap()),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, Object?> map) {
    return Customer(
      id: map['id'] as int?,
      fullName: map['full_name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      minBudget: (map['min_budget'] as num?)?.toDouble(),
      maxBudget: (map['max_budget'] as num?)?.toDouble(),
      notes: map['notes'] as String? ?? '',
      requestFilter: CustomerRequestFilter.fromJson(
        map['request_json'] as String?,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

class CustomerRequestFilter {
  const CustomerRequestFilter({
    this.dealType,
    this.type,
    this.placeKind,
    this.placeName,
    this.streetName,
    this.housingKind,
    this.blockNo,
    this.parcelNo,
    this.roomLayout,
    this.minSquareMeters,
    this.maxSquareMeters,
    this.areaUnit = AreaUnit.squareMeter,
    this.maxBuildingAge,
    this.minBathroomCount,
    this.minBalconyCount,
    this.floorCount,
    this.floorNumber,
    this.frontage,
  });

  final DealType? dealType;
  final PropertyType? type;
  final PlaceKind? placeKind;
  final String? placeName;
  final String? streetName;
  final HousingKind? housingKind;
  final String? blockNo;
  final String? parcelNo;
  final String? roomLayout;
  final double? minSquareMeters;
  final double? maxSquareMeters;
  final AreaUnit areaUnit;
  final int? maxBuildingAge;
  final int? minBathroomCount;
  final int? minBalconyCount;
  final int? floorCount;
  final int? floorNumber;
  final String? frontage;

  int get activeCount {
    var count = 0;
    if (dealType != null) count++;
    if (type != null) count++;
    if (placeKind != null) count++;
    if (_hasText(placeName)) count++;
    if (_hasText(streetName)) count++;
    if (housingKind != null) count++;
    if (_hasText(blockNo)) count++;
    if (_hasText(parcelNo)) count++;
    if (_hasText(roomLayout)) count++;
    if (minSquareMeters != null) count++;
    if (maxSquareMeters != null) count++;
    if (maxBuildingAge != null) count++;
    if (minBathroomCount != null) count++;
    if (minBalconyCount != null) count++;
    if (floorCount != null) count++;
    if (floorNumber != null) count++;
    if (_hasText(frontage)) count++;
    return count;
  }

  bool matches(PropertyListing listing,
      {double? minBudget, double? maxBudget}) {
    if (listing.isDeleted || listing.isSold) {
      return false;
    }
    if (minBudget != null && listing.salePrice < minBudget) {
      return false;
    }
    if (maxBudget != null && listing.salePrice > maxBudget) {
      return false;
    }
    if (dealType != null && listing.dealType != dealType) {
      return false;
    }
    if (type != null && listing.type != type) {
      return false;
    }
    if (placeKind != null && listing.placeKind != placeKind) {
      return false;
    }
    if (_hasText(placeName) && listing.placeName != placeName) {
      return false;
    }
    if (_hasText(streetName) && listing.streetName != streetName) {
      return false;
    }
    if (housingKind != null && listing.housingKind != housingKind) {
      return false;
    }
    if (_hasText(blockNo) && !_contains(listing.blockNo, blockNo)) {
      return false;
    }
    if (_hasText(parcelNo) && !_contains(listing.parcelNo, parcelNo)) {
      return false;
    }
    if (_hasText(roomLayout) && !_contains(listing.roomLayout, roomLayout)) {
      return false;
    }
    if (minSquareMeters != null &&
        ((listing.squareMeters ?? 0) < minSquareMeters!)) {
      return false;
    }
    if (maxSquareMeters != null &&
        ((listing.squareMeters ?? double.infinity) > maxSquareMeters!)) {
      return false;
    }
    if (maxBuildingAge != null &&
        ((listing.buildingAge ?? double.infinity) > maxBuildingAge!)) {
      return false;
    }
    if (minBathroomCount != null &&
        ((listing.bathroomCount ?? 0) < minBathroomCount!)) {
      return false;
    }
    if (minBalconyCount != null &&
        ((listing.balconyCount ?? 0) < minBalconyCount!)) {
      return false;
    }
    if (floorCount != null && listing.floorCount != floorCount) {
      return false;
    }
    if (floorNumber != null && listing.floorNumber != floorNumber) {
      return false;
    }
    if (_hasText(frontage) && !_contains(listing.frontage, frontage)) {
      return false;
    }
    return true;
  }

  CustomerRequestFilter copyWith({
    DealType? dealType,
    PropertyType? type,
    PlaceKind? placeKind,
    String? placeName,
    String? streetName,
    HousingKind? housingKind,
    String? blockNo,
    String? parcelNo,
    String? roomLayout,
    double? minSquareMeters,
    double? maxSquareMeters,
    AreaUnit? areaUnit,
    int? maxBuildingAge,
    int? minBathroomCount,
    int? minBalconyCount,
    int? floorCount,
    int? floorNumber,
    String? frontage,
  }) {
    return CustomerRequestFilter(
      dealType: dealType ?? this.dealType,
      type: type ?? this.type,
      placeKind: placeKind ?? this.placeKind,
      placeName: placeName ?? this.placeName,
      streetName: streetName ?? this.streetName,
      housingKind: housingKind ?? this.housingKind,
      blockNo: blockNo ?? this.blockNo,
      parcelNo: parcelNo ?? this.parcelNo,
      roomLayout: roomLayout ?? this.roomLayout,
      minSquareMeters: minSquareMeters ?? this.minSquareMeters,
      maxSquareMeters: maxSquareMeters ?? this.maxSquareMeters,
      areaUnit: areaUnit ?? this.areaUnit,
      maxBuildingAge: maxBuildingAge ?? this.maxBuildingAge,
      minBathroomCount: minBathroomCount ?? this.minBathroomCount,
      minBalconyCount: minBalconyCount ?? this.minBalconyCount,
      floorCount: floorCount ?? this.floorCount,
      floorNumber: floorNumber ?? this.floorNumber,
      frontage: frontage ?? this.frontage,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'dealType': dealType?.name,
      'type': type?.name,
      'placeKind': placeKind?.name,
      'placeName': _emptyToNull(placeName),
      'streetName': _emptyToNull(streetName),
      'housingKind': housingKind?.name,
      'blockNo': _emptyToNull(blockNo),
      'parcelNo': _emptyToNull(parcelNo),
      'roomLayout': _emptyToNull(roomLayout),
      'minSquareMeters': minSquareMeters,
      'maxSquareMeters': maxSquareMeters,
      'areaUnit': areaUnit.name,
      'maxBuildingAge': maxBuildingAge,
      'minBathroomCount': minBathroomCount,
      'minBalconyCount': minBalconyCount,
      'floorCount': floorCount,
      'floorNumber': floorNumber,
      'frontage': _emptyToNull(frontage),
    };
  }

  static CustomerRequestFilter fromJson(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const CustomerRequestFilter();
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        return const CustomerRequestFilter();
      }
      return CustomerRequestFilter.fromMap({
        for (final entry in decoded.entries) entry.key.toString(): entry.value,
      });
    } catch (_) {
      return const CustomerRequestFilter();
    }
  }

  factory CustomerRequestFilter.fromMap(Map<String, Object?> map) {
    return CustomerRequestFilter(
      dealType: DealType.fromStorage(map['dealType'] as String?),
      type: _propertyTypeFromStorage(map['type'] as String?),
      placeKind: _placeKindFromStorage(map['placeKind'] as String?),
      placeName: map['placeName'] as String?,
      streetName: map['streetName'] as String?,
      housingKind: HousingKind.fromStorage(map['housingKind'] as String?),
      blockNo: map['blockNo'] as String?,
      parcelNo: map['parcelNo'] as String?,
      roomLayout: map['roomLayout'] as String?,
      minSquareMeters: (map['minSquareMeters'] as num?)?.toDouble(),
      maxSquareMeters: (map['maxSquareMeters'] as num?)?.toDouble(),
      areaUnit: AreaUnit.fromStorage(map['areaUnit'] as String?),
      maxBuildingAge: (map['maxBuildingAge'] as num?)?.toInt(),
      minBathroomCount: (map['minBathroomCount'] as num?)?.toInt(),
      minBalconyCount: (map['minBalconyCount'] as num?)?.toInt(),
      floorCount: (map['floorCount'] as num?)?.toInt(),
      floorNumber: (map['floorNumber'] as num?)?.toInt(),
      frontage: map['frontage'] as String?,
    );
  }

  static bool _contains(String? value, String? query) {
    final normalizedValue = _normalize(value ?? '');
    final normalizedQuery = _normalize(query ?? '');
    if (normalizedQuery.isEmpty) {
      return true;
    }
    return normalizedValue.contains(normalizedQuery);
  }

  static bool _hasText(String? value) => (value ?? '').trim().isNotEmpty;

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('\u0307', '')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static PropertyType? _propertyTypeFromStorage(String? value) {
    if (value == null) {
      return null;
    }
    return PropertyType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => PropertyType.apartment,
    );
  }

  static PlaceKind? _placeKindFromStorage(String? value) {
    if (value == null) {
      return null;
    }
    return PlaceKind.values.firstWhere(
      (kind) => kind.name == value,
      orElse: () => PlaceKind.neighborhood,
    );
  }
}
