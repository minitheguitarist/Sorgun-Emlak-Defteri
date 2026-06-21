import 'dart:convert';

import 'property_type.dart';

class PropertyListing {
  const PropertyListing({
    this.id,
    required this.type,
    required this.placeKind,
    required this.placeName,
    required this.streetName,
    this.buildingName,
    this.blockNo,
    this.parcelNo,
    this.roomLayout,
    this.squareMeters,
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
  final PlaceKind placeKind;
  final String placeName;
  final String streetName;
  final String? buildingName;
  final String? blockNo;
  final String? parcelNo;
  final String? roomLayout;
  final double? squareMeters;
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
    PlaceKind? placeKind,
    String? placeName,
    String? streetName,
    String? buildingName,
    String? blockNo,
    String? parcelNo,
    String? roomLayout,
    double? squareMeters,
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
      placeKind: placeKind ?? this.placeKind,
      placeName: placeName ?? this.placeName,
      streetName: streetName ?? this.streetName,
      buildingName: buildingName ?? this.buildingName,
      blockNo: blockNo ?? this.blockNo,
      parcelNo: parcelNo ?? this.parcelNo,
      roomLayout: roomLayout ?? this.roomLayout,
      squareMeters: squareMeters ?? this.squareMeters,
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
      'place_kind': placeKind.name,
      'place_name': placeName,
      'street_name': streetName,
      'building_name': buildingName,
      'block_no': blockNo,
      'parcel_no': parcelNo,
      'room_layout': roomLayout,
      'square_meters': squareMeters,
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
      placeKind: PlaceKind.fromStorage(map['place_kind'] as String),
      placeName: map['place_name'] as String,
      streetName: map['street_name'] as String? ?? '',
      buildingName: map['building_name'] as String?,
      blockNo: map['block_no'] as String?,
      parcelNo: map['parcel_no'] as String?,
      roomLayout: map['room_layout'] as String?,
      squareMeters: (map['square_meters'] as num?)?.toDouble(),
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
