import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/app_database.dart';
import '../services/data_transfer_service.dart';
import '../services/package_picker_service.dart';

class DataTransferScreen extends StatefulWidget {
  const DataTransferScreen({
    super.key,
    required this.database,
    required this.onImported,
  });

  final AppDatabase database;
  final VoidCallback onImported;

  @override
  State<DataTransferScreen> createState() => _DataTransferScreenState();
}

class _DataTransferScreenState extends State<DataTransferScreen> {
  late final DataTransferService _service;
  late final PackagePickerService _packagePicker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service = DataTransferService(database: widget.database);
    _packagePicker = PackagePickerService();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
      children: [
        Text(
          'Veri aktarımı',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Üç telefon arasında son gönderilen paket doğru veri kabul edilir. İçe aktarma mevcut verinin üstüne yazar.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: _busy ? null : _exportPackage,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.ios_share_outlined),
          label: const Text('Paylaşım paketi oluştur'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _importPackage,
          icon: const Icon(Icons.file_open_outlined),
          label: const Text('Paylaşım paketini içe aktar'),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Paket ilanları, müşterileri, ilgi bağlantılarını, satılanları, fiyat geçmişini ve fotoğrafları birlikte taşır. Yanlış dosya içe aktarılırsa işlem öncesi otomatik yedek paketi oluşturulur.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _exportPackage() async {
    setState(() => _busy = true);
    try {
      final file = await _service.createPackage();
      await SharePlus.instance.share(
        ShareParams(
          title: 'Sorgun Emlak Defteri veri paketi',
          text: 'Sorgun Emlak Defteri veri paketi',
          files: [XFile(file.path)],
          fileNameOverrides: ['sorgun-emlak-defteri.sedef'],
        ),
      );
      _showSnack('Paylaşım paketi hazırlandı.');
    } catch (error) {
      _showSnack('Paket oluşturulamadı: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _importPackage() async {
    final path = await _packagePicker.pickPackage();
    if (path == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verinin üstüne yazılsın mı?'),
        content: const Text(
          'Bu işlem telefondaki mevcut ilanları, müşterileri, fiyat geçmişini ve fotoğrafları seçilen paketteki veriyle değiştirir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('İçe aktar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() => _busy = true);
    try {
      final summary = await _service.importPackage(path);
      widget.onImported();
      _showSnack(
        '${summary.listingCount} ilan, ${summary.customerCount} müşteri ve ${summary.photoCount} fotoğraf içe aktarıldı. Yedek: ${summary.backupPath}',
      );
    } catch (error) {
      _showSnack('Paket içe aktarılamadı: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
