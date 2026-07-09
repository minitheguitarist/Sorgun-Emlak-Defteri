enum PropertyType {
  apartment,
  land,
  field;

  String get label {
    switch (this) {
      case PropertyType.apartment:
        return 'Daire';
      case PropertyType.land:
        return 'Arsa';
      case PropertyType.field:
        return 'Tarla';
    }
  }

  static PropertyType fromStorage(String value) {
    return PropertyType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => PropertyType.apartment,
    );
  }
}

enum DealType {
  sale,
  rent;

  String get label {
    switch (this) {
      case DealType.sale:
        return 'Satılık';
      case DealType.rent:
        return 'Kiralık';
    }
  }

  String get priceLabel {
    switch (this) {
      case DealType.sale:
        return 'Satış fiyatı';
      case DealType.rent:
        return 'Kira fiyatı';
    }
  }

  static DealType? fromStorage(String? value) {
    if (value == null) {
      return null;
    }
    return DealType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => DealType.sale,
    );
  }
}

enum PlaceKind {
  neighborhood,
  village;

  String get label {
    switch (this) {
      case PlaceKind.neighborhood:
        return 'Mahalle';
      case PlaceKind.village:
        return 'Köy';
    }
  }

  static PlaceKind fromStorage(String value) {
    return PlaceKind.values.firstWhere(
      (kind) => kind.name == value,
      orElse: () => PlaceKind.neighborhood,
    );
  }
}

enum HousingKind {
  apartment,
  site,
  detached;

  String get label {
    switch (this) {
      case HousingKind.apartment:
        return 'Apartman';
      case HousingKind.site:
        return 'Site';
      case HousingKind.detached:
        return 'Müstakil';
    }
  }

  static HousingKind? fromStorage(String? value) {
    if (value == null) {
      return null;
    }
    return HousingKind.values.firstWhere(
      (kind) => kind.name == value,
      orElse: () => HousingKind.apartment,
    );
  }
}

enum AreaUnit {
  squareMeter,
  decare;

  String get label {
    switch (this) {
      case AreaUnit.squareMeter:
        return 'Metrekare';
      case AreaUnit.decare:
        return 'Dönüm';
    }
  }

  String get suffix {
    switch (this) {
      case AreaUnit.squareMeter:
        return 'm²';
      case AreaUnit.decare:
        return 'dönüm';
    }
  }

  double toSquareMeters(double value) {
    switch (this) {
      case AreaUnit.squareMeter:
        return value;
      case AreaUnit.decare:
        return value * 1000;
    }
  }

  double fromSquareMeters(num value) {
    switch (this) {
      case AreaUnit.squareMeter:
        return value.toDouble();
      case AreaUnit.decare:
        return value / 1000;
    }
  }

  static AreaUnit fromStorage(String? value) {
    if (value == null) {
      return AreaUnit.squareMeter;
    }
    return AreaUnit.values.firstWhere(
      (unit) => unit.name == value,
      orElse: () => AreaUnit.squareMeter,
    );
  }
}
