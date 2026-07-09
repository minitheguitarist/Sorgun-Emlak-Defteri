import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/app_database.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.database,
    this.standalone = false,
  });

  final AppDatabase database;
  final bool standalone;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _agencyNameController = TextEditingController();
  final _agentNameController = TextEditingController();
  final _agentPhoneController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _agencyNameController.dispose();
    _agentNameController.dispose();
    _agentPhoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await widget.database.getAppSettings();
    if (!mounted) {
      return;
    }
    _agencyNameController.text = settings.agencyName;
    _agentNameController.text = settings.agentName;
    _agentPhoneController.text = settings.agentPhone;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final content = _loading
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
              children: [
                Text(
                  'Kişisel bilgilerim',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Reklam görsellerinde mülk sahibinin değil emlak ofisinin iletişim bilgileri kullanılır.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _agencyNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Emlak ofisi adı',
                    hintText: 'A Emlak',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _agentNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Ad soyad',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _agentPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefon',
                    hintText: '0 5XX XXX XX XX',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Bilgileri kaydet'),
                ),
              ],
            ),
          );

    if (!widget.standalone) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: content,
    );
  }

  String? _required(String? value) {
    return (value ?? '').trim().isEmpty ? 'Bu alan zorunlu.' : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.database.saveAppSettings(
        AppSettings(
          agencyName: _agencyNameController.text,
          agentName: _agentNameController.text,
          agentPhone: _agentPhoneController.text,
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bilgiler kaydedildi.')),
      );
      if (widget.standalone) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
