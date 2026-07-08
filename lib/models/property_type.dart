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
  detached;

  String get label {
    switch (this) {
      case HousingKind.apartment:
        return 'Apartman';
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
