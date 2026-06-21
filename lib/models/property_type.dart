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
