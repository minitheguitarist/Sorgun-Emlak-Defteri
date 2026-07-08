import 'dart:convert';
import 'dart:io';

import '../models/property_type.dart';
import 'address_repository.dart';

class AddressSuggestion {
  const AddressSuggestion({
    required this.rawAddress,
    required this.placeKind,
    required this.placeName,
    required this.streetName,
    required this.rawPlaceName,
    required this.rawStreetName,
  });

  final String rawAddress;
  final PlaceKind placeKind;
  final String? placeName;
  final String? streetName;
  final String? rawPlaceName;
  final String? rawStreetName;
}

class ReverseGeocodingService {
  const ReverseGeocodingService();

  Future<AddressSuggestion> suggestAddress({
    required double latitude,
    required double longitude,
    required AddressBook addressBook,
  }) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'addressdetails': '1',
      'accept-language': 'tr',
    });

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'SorgunEmlakDefteri/1.0.3 (com.sorgunemlak.defter)',
      );
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
            'Adres servisi yanıt vermedi: ${response.statusCode}');
      }

      final body = await utf8.decodeStream(response);
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Adres yanıtı okunamadı.');
      }

      final address = decoded['address'];
      if (address is! Map<String, dynamic>) {
        throw const FormatException('Adres bulunamadı.');
      }

      final rawVillage = _firstText(address, const ['village', 'hamlet']);
      final rawNeighborhood = _firstText(address, const [
        'neighbourhood',
        'suburb',
        'quarter',
        'city_district',
      ]);
      final rawStreet = _firstText(address, const [
        'road',
        'residential',
        'pedestrian',
        'footway',
        'path',
      ]);

      final placeKind =
          rawVillage == null ? PlaceKind.neighborhood : PlaceKind.village;
      final placeOptions = addressBook.placesFor(placeKind);
      final rawPlace = rawVillage ?? rawNeighborhood;

      return AddressSuggestion(
        rawAddress: decoded['display_name'] as String? ?? '',
        placeKind: placeKind,
        placeName: _matchOption(rawPlace, placeOptions),
        streetName: _matchOption(rawStreet, addressBook.streets),
        rawPlaceName: rawPlace,
        rawStreetName: rawStreet,
      );
    } finally {
      client.close(force: true);
    }
  }

  static String? _firstText(Map<String, dynamic> values, List<String> keys) {
    for (final key in keys) {
      final value = values[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static String? _matchOption(String? rawValue, List<String> options) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }
    final raw = _normalize(rawValue);
    for (final option in options) {
      if (_normalize(option) == raw) {
        return option;
      }
    }
    for (final option in options) {
      final normalized = _normalize(option);
      if (normalized.contains(raw) || raw.contains(normalized)) {
        return option;
      }
    }
    return null;
  }

  static String _normalize(String value) {
    var normalized = value
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
    normalized = normalized.replaceAll(RegExp(r'\bmahallesi\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\bmahalle\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\bmah\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\bköyü\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\bkoyu\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\bköy\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\bcaddesi\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\bcadde\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\bsokagi\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\bsokak\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\byolu\b'), '');
    normalized = normalized.replaceAll(RegExp(r'\byol\b'), '');
    return normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}
