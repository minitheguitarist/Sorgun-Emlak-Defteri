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
    this.buildingAge,
    this.bathroomCount,
    this.balconyCount,
    this.housingKind,
    this.latitude,
    this.longitude,
    this.ownerName,
    this.ownerPhone,
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
  final int? buildingAge;
  final int? bathroomCount;
  final int? balconyCount;
  final HousingKind? housingKind;
  final double? latitude;
  final double? longitude;
  final String? ownerName;
  final String? ownerPhone;
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
    int? buildingAge,
    int? bathroomCount,
    int? balconyCount,
    HousingKind? housingKind,
    double? latitude,
    double? longitude,
    String? ownerName,
    String? ownerPhone,
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
      buildingAge: buildingAge ?? this.buildingAge,
      bathroomCount: bathroomCount ?? this.bathroomCount,
      balconyCount: balconyCount ?? this.balconyCount,
      housingKind: housingKind ?? this.housingKind,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
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
      'building_age': buildingAge,
      'bathroom_count': bathroomCount,
      'balcony_count': balconyCount,
      'housing_kind': housingKind?.name,
      'latitude': latitude,
      'longitude': longitude,
      'owner_name': ownerName,
      'owner_phone': ownerPhone,
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
      buildingAge: (map['building_age'] as num?)?.toInt(),
      bathroomCount: (map['bathroom_count'] as num?)?.toInt(),
      balconyCount: (map['balcony_count'] as num?)?.toInt(),
      housingKind: HousingKind.fromStorage(map['housing_kind'] as String?),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      ownerName: map['owner_name'] as String?,
      ownerPhone: map['owner_phone'] as String?,
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
}
