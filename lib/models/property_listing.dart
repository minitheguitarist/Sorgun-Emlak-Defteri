import 'dart:convert';

import 'property_type.dart';

class PropertyListing {
  const PropertyListing({
    this.id,
    required this.type,
    this.dealType,
    required this.placeKind,
    required this.placeName,
    required this.streetName,
    this.buildingName,
    this.blockNo,
    this.parcelNo,
    this.roomLayout,
    this.squareMeters,
    this.areaUnit,
    this.buildingAge,
    this.bathroomCount,
    this.balconyCount,
    this.housingKind,
    this.floorCount,
    this.floorNumber,
    this.frontage,
    this.zoningStatus,
    this.roadFrontage,
    this.deedStatus,
    this.utilities,
    this.latitude,
    this.longitude,
    this.ownerName,
    this.ownerPhone,
    this.ownerPhones = const [],
    required this.costPrice,
    required this.salePrice,
    required this.description,
    required this.photoPaths,
    this.isSold = false,
    this.soldPrice,
    this.soldAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final PropertyType type;
  final DealType? dealType;
  final PlaceKind placeKind;
  final String placeName;
  final String streetName;
  final String? buildingName;
  final String? blockNo;
  final String? parcelNo;
  final String? roomLayout;
  final double? squareMeters;
  final AreaUnit? areaUnit;
  final int? buildingAge;
  final int? bathroomCount;
  final int? balconyCount;
  final HousingKind? housingKind;
  final int? floorCount;
  final int? floorNumber;
  final String? frontage;
  final String? zoningStatus;
  final String? roadFrontage;
  final String? deedStatus;
  final String? utilities;
  final double? latitude;
  final double? longitude;
  final String? ownerName;
  final String? ownerPhone;
  final List<String> ownerPhones;
  final double costPrice;
  final double salePrice;
  final String description;
  final List<String> photoPaths;
  final bool isSold;
  final double? soldPrice;
  final DateTime? soldAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get activeProfit => salePrice - costPrice;

  double get activeProfitPercent {
    if (salePrice <= 0) {
      return 0;
    }
    return activeProfit / salePrice * 100;
  }

  double get finalPrice => soldPrice ?? salePrice;

  double get finalProfit => finalPrice - costPrice;

  bool get hasLocation => latitude != null && longitude != null;

  List<String> get ownerPhoneList {
    final phones = <String>[];
    void addPhone(String? value) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        return;
      }
      if (!phones.contains(trimmed)) {
        phones.add(trimmed);
      }
    }

    for (final phone in ownerPhones) {
      addPhone(phone);
    }
    addPhone(ownerPhone);
    return phones;
  }

  double get finalProfitPercent {
    if (finalPrice <= 0) {
      return 0;
    }
    return finalProfit / finalPrice * 100;
  }

  String get displayTitle {
    if (type == PropertyType.apartment) {
      final title = buildingName?.trim();
      if (title != null && title.isNotEmpty) {
        return title;
      }
      return '$placeName ${type.label}';
    }

    final firstDescriptionLine = description
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    if (firstDescriptionLine.isNotEmpty) {
      return firstDescriptionLine;
    }
    return '$placeName ${type.label}';
  }

  String get addressLine {
    final pieces = <String>[
      placeKind.label,
      placeName,
      if (streetName.isNotEmpty) streetName,
    ];
    return pieces.join(' / ');
  }

  String get parcelLine {
    return [
      if ((blockNo ?? '').trim().isNotEmpty) 'Ada $blockNo',
      if ((parcelNo ?? '').trim().isNotEmpty) 'Parsel $parcelNo',
    ].join(' / ');
  }

  String get apartmentSpecsLine {
    return [
      if ((roomLayout ?? '').trim().isNotEmpty) roomLayout!.trim(),
      if (squareMeters != null && squareMeters! > 0)
        '${squareMeters!.toStringAsFixed(squareMeters! % 1 == 0 ? 0 : 1)} m²',
    ].join(' / ');
  }

  PropertyListing copyWith({
    int? id,
    PropertyType? type,
    DealType? dealType,
    PlaceKind? placeKind,
    String? placeName,
    String? streetName,
    String? buildingName,
    String? blockNo,
    String? parcelNo,
    String? roomLayout,
    double? squareMeters,
    AreaUnit? areaUnit,
    int? buildingAge,
    int? bathroomCount,
    int? balconyCount,
    HousingKind? housingKind,
    int? floorCount,
    int? floorNumber,
    String? frontage,
    String? zoningStatus,
    String? roadFrontage,
    String? deedStatus,
    String? utilities,
    double? latitude,
    double? longitude,
    String? ownerName,
    String? ownerPhone,
    List<String>? ownerPhones,
    double? costPrice,
    double? salePrice,
    String? description,
    List<String>? photoPaths,
    bool? isSold,
    double? soldPrice,
    DateTime? soldAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PropertyListing(
      id: id ?? this.id,
      type: type ?? this.type,
      dealType: dealType ?? this.dealType,
      placeKind: placeKind ?? this.placeKind,
      placeName: placeName ?? this.placeName,
      streetName: streetName ?? this.streetName,
      buildingName: buildingName ?? this.buildingName,
      blockNo: blockNo ?? this.blockNo,
      parcelNo: parcelNo ?? this.parcelNo,
      roomLayout: roomLayout ?? this.roomLayout,
      squareMeters: squareMeters ?? this.squareMeters,
      areaUnit: areaUnit ?? this.areaUnit,
      buildingAge: buildingAge ?? this.buildingAge,
      bathroomCount: bathroomCount ?? this.bathroomCount,
      balconyCount: balconyCount ?? this.balconyCount,
      housingKind: housingKind ?? this.housingKind,
      floorCount: floorCount ?? this.floorCount,
      floorNumber: floorNumber ?? this.floorNumber,
      frontage: frontage ?? this.frontage,
      zoningStatus: zoningStatus ?? this.zoningStatus,
      roadFrontage: roadFrontage ?? this.roadFrontage,
      deedStatus: deedStatus ?? this.deedStatus,
      utilities: utilities ?? this.utilities,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      ownerPhones: ownerPhones ?? this.ownerPhones,
      costPrice: costPrice ?? this.costPrice,
      salePrice: salePrice ?? this.salePrice,
      description: description ?? this.description,
      photoPaths: photoPaths ?? this.photoPaths,
      isSold: isSold ?? this.isSold,
      soldPrice: soldPrice ?? this.soldPrice,
      soldAt: soldAt ?? this.soldAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'type': type.name,
      'deal_type': dealType?.name,
      'place_kind': placeKind.name,
      'place_name': placeName,
      'street_name': streetName,
      'building_name': buildingName,
      'block_no': blockNo,
      'parcel_no': parcelNo,
      'room_layout': roomLayout,
      'square_meters': squareMeters,
      'area_unit': areaUnit?.name,
      'building_age': buildingAge,
      'bathroom_count': bathroomCount,
      'balcony_count': balconyCount,
      'housing_kind': housingKind?.name,
      'floor_count': floorCount,
      'floor_number': floorNumber,
      'frontage': frontage,
      'zoning_status': zoningStatus,
      'road_frontage': roadFrontage,
      'deed_status': deedStatus,
      'utilities': utilities,
      'latitude': latitude,
      'longitude': longitude,
      'owner_name': ownerName,
      'owner_phone': ownerPhone ?? _firstPhone(ownerPhones),
      'owner_phones_json': jsonEncode(ownerPhoneList),
      'cost_price': costPrice,
      'sale_price': salePrice,
      'description': description,
      'photos_json': jsonEncode(photoPaths),
      'is_sold': isSold ? 1 : 0,
      'sold_price': soldPrice,
      'sold_at': soldAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PropertyListing.fromMap(Map<String, Object?> map) {
    final photos = jsonDecode(map['photos_json'] as String? ?? '[]');
    final ownerPhones = _decodeStringList(map['owner_phones_json']);
    final ownerPhone = map['owner_phone'] as String?;
    if (ownerPhone != null && ownerPhone.trim().isNotEmpty) {
      final trimmed = ownerPhone.trim();
      if (!ownerPhones.contains(trimmed)) {
        ownerPhones.insert(0, trimmed);
      }
    }
    return PropertyListing(
      id: map['id'] as int?,
      type: PropertyType.fromStorage(map['type'] as String),
      dealType: DealType.fromStorage(map['deal_type'] as String?),
      placeKind: PlaceKind.fromStorage(map['place_kind'] as String),
      placeName: map['place_name'] as String,
      streetName: map['street_name'] as String? ?? '',
      buildingName: map['building_name'] as String?,
      blockNo: map['block_no'] as String?,
      parcelNo: map['parcel_no'] as String?,
      roomLayout: map['room_layout'] as String?,
      squareMeters: (map['square_meters'] as num?)?.toDouble(),
      areaUnit: AreaUnit.fromStorage(map['area_unit'] as String?),
      buildingAge: (map['building_age'] as num?)?.toInt(),
      bathroomCount: (map['bathroom_count'] as num?)?.toInt(),
      balconyCount: (map['balcony_count'] as num?)?.toInt(),
      housingKind: HousingKind.fromStorage(map['housing_kind'] as String?),
      floorCount: (map['floor_count'] as num?)?.toInt(),
      floorNumber: (map['floor_number'] as num?)?.toInt(),
      frontage: map['frontage'] as String?,
      zoningStatus: map['zoning_status'] as String?,
      roadFrontage: map['road_frontage'] as String?,
      deedStatus: map['deed_status'] as String?,
      utilities: map['utilities'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      ownerName: map['owner_name'] as String?,
      ownerPhone: ownerPhone,
      ownerPhones: ownerPhones,
      costPrice: (map['cost_price'] as num).toDouble(),
      salePrice: (map['sale_price'] as num).toDouble(),
      description: map['description'] as String? ?? '',
      photoPaths: (photos as List<dynamic>).cast<String>(),
      isSold: (map['is_sold'] as int? ?? 0) == 1,
      soldPrice: (map['sold_price'] as num?)?.toDouble(),
      soldAt: map['sold_at'] == null
          ? null
          : DateTime.parse(map['sold_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static String? _firstPhone(List<String> phones) {
    for (final phone in phones) {
      final trimmed = phone.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  static List<String> _decodeStringList(Object? value) {
    if (value == null) {
      return <String>[];
    }
    try {
      final decoded = jsonDecode(value as String? ?? '[]');
      if (decoded is! List) {
        return <String>[];
      }
      return decoded
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();
    } catch (_) {
      return <String>[];
    }
  }
}
