import 'package:flutter/services.dart';

class ContactSelection {
  const ContactSelection({
    required this.name,
    required this.phones,
  });

  final String name;
  final List<String> phones;

  bool get isEmpty => name.trim().isEmpty && phones.isEmpty;
}

class ContactPickerService {
  const ContactPickerService();

  static const _channel =
      MethodChannel('com.sorgunemlak.defter/contact_picker');

  Future<ContactSelection?> pickContact() async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'pickContact',
    );
    if (result == null) {
      return null;
    }

    final rawPhones = result['phones'];
    final phones = rawPhones is List
        ? rawPhones
            .map((phone) => phone.toString().trim())
            .where((phone) => phone.isNotEmpty)
            .toSet()
            .toList()
        : <String>[];

    return ContactSelection(
      name: result['name']?.toString().trim() ?? '',
      phones: phones,
    );
  }
}
