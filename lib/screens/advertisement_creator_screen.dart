import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../models/property_listing.dart';
import '../models/property_type.dart';
import '../services/app_database.dart';
import '../services/formatters.dart';
import '../services/gallery_saver_service.dart';
import '../services/photo_service.dart';
import 'settings_screen.dart';

enum _AdvertisementTemplate {
  apartmentClassic,
  apartmentLight,
  landField;

  String get label {
    switch (this) {
      case _AdvertisementTemplate.apartmentClassic:
        return 'Daire 1';
      case _AdvertisementTemplate.apartmentLight:
        return 'Daire 2';
      case _AdvertisementTemplate.landField:
        return 'Arsa/Tarla';
    }
  }
}

class AdvertisementCreatorScreen extends StatefulWidget {
  const AdvertisementCreatorScreen({
    super.key,
    required this.database,
    required this.listing,
  });

  final AppDatabase database;
  final PropertyListing listing;

  @override
  State<AdvertisementCreatorScreen> createState() =>
      _AdvertisementCreatorScreenState();
}

class _AdvertisementCreatorScreenState
    extends State<AdvertisementCreatorScreen> {
  static const _galleryChoice = '__gallery__';

  final _previewKey = GlobalKey();
  final _gallerySaver = const GallerySaverService();
  final _photoService = PhotoService();
  late Future<AppSettings> _settingsFuture;
  late _AdvertisementTemplate _template;
  late List<String?> _photoSlots;
  bool _saving = false;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _settingsFuture = widget.database.getAppSettings();
    _template = widget.listing.type == PropertyType.apartment
        ? _AdvertisementTemplate.apartmentClassic
        : _AdvertisementTemplate.landField;
    _photoSlots = _initialSlots(_slotCountFor(_template));
  }

  List<String?> _initialSlots(int count) {
    return List<String?>.generate(
      count,
      (index) => index < widget.listing.photoPaths.length
          ? widget.listing.photoPaths[index]
          : null,
    );
  }

  int _slotCountFor(_AdvertisementTemplate template) {
    switch (template) {
      case _AdvertisementTemplate.apartmentClassic:
        return 5;
      case _AdvertisementTemplate.apartmentLight:
        return 5;
      case _AdvertisementTemplate.landField:
        return 4;
    }
  }

  bool get _hasMainPhoto {
    final path = _slotPath(0);
    return path != null && File(path).existsSync();
  }

  String? _slotPath(int index) {
    if (index < 0 || index >= _photoSlots.length) {
      return null;
    }
    return _photoSlots[index];
  }

  void _selectTemplate(_AdvertisementTemplate template) {
    final count = _slotCountFor(template);
    setState(() {
      _template = template;
      if (_photoSlots.length < count) {
        _photoSlots = [
          ..._photoSlots,
          ...List<String?>.filled(count - _photoSlots.length, null),
        ];
      } else if (_photoSlots.length > count) {
        _photoSlots = _photoSlots.take(count).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reklam oluştur')),
      body: FutureBuilder<AppSettings>(
        future: _settingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final settings = snapshot.data ?? const AppSettings();
          if (!settings.isComplete) {
            return _MissingSettings(
              onOpenSettings: _openSettings,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
            children: [
              if (widget.listing.type == PropertyType.apartment) ...[
                SegmentedButton<_AdvertisementTemplate>(
                  segments: const [
                    ButtonSegment<_AdvertisementTemplate>(
                      value: _AdvertisementTemplate.apartmentClassic,
                      icon: Icon(Icons.dashboard_customize_outlined),
                      label: Text('Taslak 1'),
                    ),
                    ButtonSegment<_AdvertisementTemplate>(
                      value: _AdvertisementTemplate.apartmentLight,
                      icon: Icon(Icons.view_quilt_outlined),
                      label: Text('Taslak 2'),
                    ),
                  ],
                  selected: {_template},
                  onSelectionChanged: (value) => _selectTemplate(value.first),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                'Fotoğrafa dokunarak değiştirebilirsiniz.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 9 / 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: RepaintBoundary(
                        key: _previewKey,
                        child: SizedBox(
                          width: 360,
                          height: 640,
                          child: _AdvertisementCanvas(
                            listing: widget.listing,
                            settings: settings,
                            template: _template,
                            photoSlots: _photoSlots,
                            showEditBadges: !_capturing,
                            onPickSlot: _pickSlot,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (!_hasMainPhoto)
                Text(
                  'Kaydetmek için en az ana görsel seçin.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed:
                    _saving || !_hasMainPhoto ? null : () => _save(settings),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_library_outlined),
                label: const Text('Galeriye kaydet'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          database: widget.database,
          standalone: true,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _settingsFuture = widget.database.getAppSettings());
  }

  Future<void> _pickSlot(int index) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final listingPhotos = widget.listing.photoPaths
            .where((path) => File(path).existsSync())
            .toList();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Fotoğraf seç',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 12),
                if (listingPhotos.isNotEmpty)
                  SizedBox(
                    height: 190,
                    child: GridView.builder(
                      scrollDirection: Axis.horizontal,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: listingPhotos.length,
                      itemBuilder: (context, photoIndex) {
                        final path = listingPhotos[photoIndex];
                        return InkWell(
                          onTap: () => Navigator.of(context).pop(path),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(path),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  const Text('Bu ilanda kayıtlı fotoğraf yok.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(_galleryChoice),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galeriden seç'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || selected == null) {
      return;
    }

    if (selected == _galleryChoice) {
      try {
        final paths = await _photoService.pickFromGallery();
        if (!mounted || paths.isEmpty) {
          return;
        }
        setState(() => _photoSlots[index] = paths.first);
      } catch (error) {
        _showSnack('Fotoğraf seçilemedi: $error');
      }
      return;
    }

    setState(() => _photoSlots[index] = selected);
  }

  Future<void> _save(AppSettings settings) async {
    setState(() {
      _saving = true;
      _capturing = true;
    });
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _previewKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Reklam önizlemesi hazırlanamadı.');
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('Reklam görseli oluşturulamadı.');
      }

      final bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
      await _gallerySaver.savePng(
        bytes: bytes,
        fileName: _advertisementFileName(settings),
      );
      if (mounted) {
        _showSnack('Reklam galeriye kaydedildi.');
      }
    } on PlatformException catch (error) {
      _showSnack('Reklam kaydedilemedi: ${error.message ?? error.code}');
    } catch (error) {
      _showSnack('Reklam kaydedilemedi: $error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _capturing = false;
        });
      }
    }
  }

  String _advertisementFileName(AppSettings settings) {
    final agency = settings.agencyName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final id = widget.listing.id ?? DateTime.now().microsecondsSinceEpoch;
    return '${agency.isEmpty ? 'sorgun-emlak' : agency}-reklam-$id.png';
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

class _MissingSettings extends StatelessWidget {
  const _MissingSettings({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_accounts_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'Kişisel bilgiler eksik',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reklamda emlak ofisi adı, ad soyad ve telefon kullanılacağı için önce bu bilgileri kaydedin.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Kişisel bilgileri aç'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvertisementCanvas extends StatelessWidget {
  const _AdvertisementCanvas({
    required this.listing,
    required this.settings,
    required this.template,
    required this.photoSlots,
    required this.showEditBadges,
    required this.onPickSlot,
  });

  final PropertyListing listing;
  final AppSettings settings;
  final _AdvertisementTemplate template;
  final List<String?> photoSlots;
  final bool showEditBadges;
  final ValueChanged<int> onPickSlot;

  @override
  Widget build(BuildContext context) {
    switch (template) {
      case _AdvertisementTemplate.apartmentClassic:
        return _ApartmentClassicAd(
          listing: listing,
          settings: settings,
          photoSlots: photoSlots,
          showEditBadges: showEditBadges,
          onPickSlot: onPickSlot,
        );
      case _AdvertisementTemplate.apartmentLight:
        return _ApartmentLightAd(
          listing: listing,
          settings: settings,
          photoSlots: photoSlots,
          showEditBadges: showEditBadges,
          onPickSlot: onPickSlot,
        );
      case _AdvertisementTemplate.landField:
        return _LandFieldAd(
          listing: listing,
          settings: settings,
          photoSlots: photoSlots,
          showEditBadges: showEditBadges,
          onPickSlot: onPickSlot,
        );
    }
  }
}

class _ApartmentClassicAd extends StatelessWidget {
  const _ApartmentClassicAd({
    required this.listing,
    required this.settings,
    required this.photoSlots,
    required this.showEditBadges,
    required this.onPickSlot,
  });

  final PropertyListing listing;
  final AppSettings settings;
  final List<String?> photoSlots;
  final bool showEditBadges;
  final ValueChanged<int> onPickSlot;

  @override
  Widget build(BuildContext context) {
    final specs = _apartmentSpecs(listing).take(5).toList();
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF8F6F1)),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Column(
          children: [
            Expanded(
              flex: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: 32,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                      decoration: BoxDecoration(
                        color: _dark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _dealLabel(listing),
                            style: const TextStyle(
                              color: _gold,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _apartmentRoom(listing),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 43,
                              height: 0.95,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'DAİRE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(height: 1.5, color: _gold),
                          const SizedBox(height: 14),
                          for (final spec in specs) ...[
                            _ClassicSpec(spec: spec),
                            const SizedBox(height: 9),
                          ],
                          const Spacer(),
                          Text(
                            settings.agencyName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 68,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _AdPhoto(
                            path: _slot(photoSlots, 0),
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => onPickSlot(0),
                            showEditBadge: showEditBadges,
                          ),
                        ),
                        Positioned(
                          right: 16,
                          top: 0,
                          child: _Ribbon(listing: listing),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Expanded(
                    child: _AdPhoto(
                      path: _slot(photoSlots, 1),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onPickSlot(1),
                      showEditBadge: showEditBadges,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _AdPhoto(
                      path: _slot(photoSlots, 2),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onPickSlot(2),
                      showEditBadge: showEditBadges,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _AdPhoto(
                      path: _slot(photoSlots, 3),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onPickSlot(3),
                      showEditBadge: showEditBadges,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              flex: 1,
              child: _Footer(settings: settings, dark: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApartmentLightAd extends StatelessWidget {
  const _ApartmentLightAd({
    required this.listing,
    required this.settings,
    required this.photoSlots,
    required this.showEditBadges,
    required this.onPickSlot,
  });

  final PropertyListing listing;
  final AppSettings settings;
  final List<String?> photoSlots;
  final bool showEditBadges;
  final ValueChanged<int> onPickSlot;

  @override
  Widget build(BuildContext context) {
    final specs = _apartmentSpecs(listing).take(5).toList();
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFFBFAF7)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 255,
              child: _AdPhoto(
                path: _slot(photoSlots, 0),
                borderRadius: BorderRadius.circular(8),
                onTap: () => onPickSlot(0),
                showEditBadge: showEditBadges,
              ),
            ),
            const SizedBox(height: 10),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.home_outlined, color: _gold, size: 28),
                      const SizedBox(height: 4),
                      Text(
                        '${_dealLabel(listing)} ${_apartmentRoom(listing)} DAİRE',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF2B2D31),
                          fontSize: 25,
                          height: 1.02,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _shortLine(listing),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _gold,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 0,
                  top: -56,
                  child: Container(
                    width: 108,
                    height: 116,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: _AdPhoto(
                            path: _slot(photoSlots, 1),
                            borderRadius: BorderRadius.circular(7),
                            onTap: () => onPickSlot(1),
                            showEditBadge: showEditBadges,
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: _gold,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'DIŞ CEPHE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < specs.length; i++) ...[
                  Expanded(child: _LightSpec(spec: specs[i])),
                  if (i != specs.length - 1) const SizedBox(width: 3),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _LabeledPhoto(
                      path: _slot(photoSlots, 2),
                      label: 'İÇ MEKAN',
                      onTap: () => onPickSlot(2),
                      showEditBadge: showEditBadges,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _LabeledPhoto(
                      path: _slot(photoSlots, 3),
                      label: 'ODA',
                      onTap: () => onPickSlot(3),
                      showEditBadge: showEditBadges,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _LabeledPhoto(
                      path: _slot(photoSlots, 4),
                      label: 'DETAY',
                      onTap: () => onPickSlot(4),
                      showEditBadge: showEditBadges,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
                height: 58, child: _Footer(settings: settings, dark: true)),
          ],
        ),
      ),
    );
  }
}

class _LandFieldAd extends StatelessWidget {
  const _LandFieldAd({
    required this.listing,
    required this.settings,
    required this.photoSlots,
    required this.showEditBadges,
    required this.onPickSlot,
  });

  final PropertyListing listing;
  final AppSettings settings;
  final List<String?> photoSlots;
  final bool showEditBadges;
  final ValueChanged<int> onPickSlot;

  @override
  Widget build(BuildContext context) {
    final info = _landInfo(listing);
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFFAF8EF)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_dealLabel(listing)} ${listing.type == PropertyType.field ? 'TARLA' : 'ARSA'}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _green,
                fontSize: 36,
                height: 0.92,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3D2A9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _shortLine(listing),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1C1C1C),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _AdPhoto(
                      path: _slot(photoSlots, 0),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onPickSlot(0),
                      showEditBadge: showEditBadges,
                    ),
                  ),
                  if (listing.squareMeters != null && listing.squareMeters! > 0)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                        child: Text(
                          formatArea(listing.squareMeters!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Expanded(
                    child: _LabeledPhoto(
                      path: _slot(photoSlots, 1),
                      label: 'KONUM',
                      onTap: () => onPickSlot(1),
                      showEditBadge: showEditBadges,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _LabeledPhoto(
                      path: _slot(photoSlots, 2),
                      label:
                          listing.type == PropertyType.field ? 'TARLA' : 'ARSA',
                      onTap: () => onPickSlot(2),
                      showEditBadge: showEditBadges,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _LabeledPhoto(
                      path: _slot(photoSlots, 3),
                      label: 'ÇEVRE',
                      onTap: () => onPickSlot(3),
                      showEditBadge: showEditBadges,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Expanded(
                    child: _InfoPanel(
                      color: _green,
                      items: info.take(4).toList(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _InfoPanel(
                      color: _green,
                      items: info.skip(4).take(4).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            SizedBox(
                height: 60, child: _Footer(settings: settings, dark: true)),
          ],
        ),
      ),
    );
  }
}

class _AdPhoto extends StatelessWidget {
  const _AdPhoto({
    required this.path,
    required this.borderRadius,
    required this.onTap,
    required this.showEditBadge,
  });

  final String? path;
  final BorderRadius borderRadius;
  final VoidCallback onTap;
  final bool showEditBadge;

  @override
  Widget build(BuildContext context) {
    final file = path == null ? null : File(path!);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (file != null && file.existsSync())
              Image.file(file, fit: BoxFit.cover)
            else
              Container(
                color: const Color(0xFFE7E2D7),
                child: const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: Color(0xFF776E60),
                  size: 32,
                ),
              ),
            if (showEditBadge)
              const Positioned(
                right: 5,
                top: 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xCC000000),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.edit, color: Colors.white, size: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LabeledPhoto extends StatelessWidget {
  const _LabeledPhoto({
    required this.path,
    required this.label,
    required this.onTap,
    required this.showEditBadge,
  });

  final String? path;
  final String label;
  final VoidCallback onTap;
  final bool showEditBadge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: _AdPhoto(
            path: path,
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            showEditBadge: showEditBadge,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: const BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClassicSpec extends StatelessWidget {
  const _ClassicSpec({required this.spec});

  final _AdSpec spec;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(spec.icon, color: _gold, size: 18),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            '${spec.label}\n${spec.value}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _LightSpec extends StatelessWidget {
  const _LightSpec({required this.spec});

  final _AdSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFE5DDD1)),
      ),
      child: Row(
        children: [
          Icon(spec.icon, color: _gold, size: 18),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${spec.label}\n${spec.value}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1F2326),
                fontSize: 9.4,
                height: 1.05,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.color,
    required this.items,
  });

  final Color color;
  final List<_AdInfo> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8CCB6)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: items
            .map(
              (item) => Expanded(
                child: Row(
                  children: [
                    Icon(item.icon, color: color, size: 17),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${item.label}: ${item.value}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1D1D1D),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Ribbon extends StatelessWidget {
  const _Ribbon({required this.listing});

  final PropertyListing listing;

  @override
  Widget build(BuildContext context) {
    final label = listing.buildingAge == null
        ? listing.housingKind?.label ?? listing.placeName
        : 'Bina yaşı\n${listing.buildingAge}';
    return ClipPath(
      clipper: _RibbonClipper(),
      child: Container(
        width: 62,
        height: 86,
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 18),
        color: _gold,
        child: Column(
          children: [
            const Icon(Icons.home_outlined, color: _dark, size: 22),
            const SizedBox(height: 4),
            Expanded(
              child: Center(
                child: Text(
                  label.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _dark,
                    fontSize: 9,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height - 16)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.settings,
    required this.dark,
  });

  final AppSettings settings;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final background = dark ? _dark : Colors.white;
    final foreground = dark ? Colors.white : _dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.phone_in_talk_outlined, color: _gold, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DETAYLI BİLGİ İÇİN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  settings.agentPhone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ),
          Text(
            settings.agencyName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdSpec {
  const _AdSpec({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _AdInfo {
  const _AdInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

List<_AdSpec> _apartmentSpecs(PropertyListing listing) {
  final specs = <_AdSpec>[];
  if (listing.squareMeters != null && listing.squareMeters! > 0) {
    specs.add(
      _AdSpec(
        icon: Icons.square_foot_outlined,
        label: 'Brüt',
        value: formatArea(listing.squareMeters!),
      ),
    );
  }
  if ((listing.frontage ?? '').trim().isNotEmpty) {
    specs.add(
      _AdSpec(
        icon: Icons.explore_outlined,
        label: 'Cephe',
        value: listing.frontage!.trim(),
      ),
    );
  }
  if (listing.floorNumber != null) {
    specs.add(
      _AdSpec(
        icon: Icons.stairs_outlined,
        label: 'Kat',
        value: listing.floorNumber.toString(),
      ),
    );
  }
  if (listing.balconyCount != null) {
    specs.add(
      _AdSpec(
        icon: Icons.balcony_outlined,
        label: 'Balkon',
        value: listing.balconyCount.toString(),
      ),
    );
  }
  if (listing.bathroomCount != null) {
    specs.add(
      _AdSpec(
        icon: Icons.bathtub_outlined,
        label: 'Banyo',
        value: listing.bathroomCount.toString(),
      ),
    );
  }
  if (listing.housingKind != null) {
    specs.add(
      _AdSpec(
        icon: Icons.home_work_outlined,
        label: 'Konut',
        value: listing.housingKind!.label,
      ),
    );
  }
  if (listing.buildingAge != null) {
    specs.add(
      _AdSpec(
        icon: Icons.history_outlined,
        label: 'Bina yaşı',
        value: listing.buildingAge.toString(),
      ),
    );
  }
  if (listing.placeName.trim().isNotEmpty) {
    specs.add(
      _AdSpec(
        icon: Icons.location_on_outlined,
        label: listing.placeKind.label,
        value: listing.placeName,
      ),
    );
  }
  return specs;
}

List<_AdInfo> _landInfo(PropertyListing listing) {
  final items = <_AdInfo>[
    const _AdInfo(
      icon: Icons.location_city_outlined,
      label: 'Konum',
      value: 'Sorgun',
    ),
    _AdInfo(
      icon: Icons.home_outlined,
      label: listing.placeKind.label,
      value: listing.placeName,
    ),
    _AdInfo(
      icon: Icons.map_outlined,
      label: 'Ada/Parsel',
      value: [
        if ((listing.blockNo ?? '').trim().isNotEmpty) listing.blockNo!.trim(),
        if ((listing.parcelNo ?? '').trim().isNotEmpty)
          listing.parcelNo!.trim(),
      ].join(' / '),
    ),
  ];
  if (listing.squareMeters != null && listing.squareMeters! > 0) {
    items.add(
      _AdInfo(
        icon: Icons.square_foot_outlined,
        label: 'Alan',
        value: formatArea(listing.squareMeters!),
      ),
    );
  }
  if ((listing.zoningStatus ?? '').trim().isNotEmpty) {
    items.add(
      _AdInfo(
        icon: Icons.terrain_outlined,
        label: 'İmar',
        value: listing.zoningStatus!.trim(),
      ),
    );
  }
  if ((listing.roadFrontage ?? '').trim().isNotEmpty) {
    items.add(
      _AdInfo(
        icon: Icons.add_road_outlined,
        label: 'Yola cephe',
        value: listing.roadFrontage!.trim(),
      ),
    );
  }
  if ((listing.deedStatus ?? '').trim().isNotEmpty) {
    items.add(
      _AdInfo(
        icon: Icons.description_outlined,
        label: 'Tapu',
        value: listing.deedStatus!.trim(),
      ),
    );
  }
  if ((listing.utilities ?? '').trim().isNotEmpty) {
    items.add(
      _AdInfo(
        icon: Icons.water_drop_outlined,
        label: 'Elektrik/Su',
        value: listing.utilities!.trim(),
      ),
    );
  }
  return items.where((item) => item.value.trim().isNotEmpty).take(8).toList();
}

String? _slot(List<String?> slots, int index) {
  return index >= 0 && index < slots.length ? slots[index] : null;
}

String _dealLabel(PropertyListing listing) {
  return (listing.dealType?.label ?? 'Satılık').toUpperCase();
}

String _apartmentRoom(PropertyListing listing) {
  final room = listing.roomLayout?.trim();
  return room == null || room.isEmpty ? '' : room;
}

String _shortLine(PropertyListing listing) {
  final firstDescriptionLine = listing.description
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  if (firstDescriptionLine.isNotEmpty) {
    return firstDescriptionLine;
  }
  return [
    listing.placeName,
    if (listing.streetName.trim().isNotEmpty) listing.streetName.trim(),
  ].join(' / ');
}

const _dark = Color(0xFF061923);
const _gold = Color(0xFFC9A15A);
const _green = Color(0xFF254F1D);
