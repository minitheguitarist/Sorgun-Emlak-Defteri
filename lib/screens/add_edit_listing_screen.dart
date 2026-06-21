import 'dart:io';

import 'package:flutter/material.dart';

import '../models/property_listing.dart';
import '../models/property_type.dart';
import '../services/address_repository.dart';
import '../services/app_database.dart';
import '../services/formatters.dart';
import '../services/photo_service.dart';

class AddEditListingScreen extends StatefulWidget {
  const AddEditListingScreen({
    super.key,
    required this.database,
    required this.addressRepository,
    required this.photoService,
    this.listing,
    this.onSaved,
    this.standalone = false,
  });

  final AppDatabase database;
  final AddressRepository addressRepository;
  final PhotoService photoService;
  final PropertyListing? listing;
  final VoidCallback? onSaved;
  final bool standalone;

  @override
  State<AddEditListingScreen> createState() => _AddEditListingScreenState();
}

class _AddEditListingScreenState extends State<AddEditListingScreen> {
  final _formKey = GlobalKey<FormState>();
  late Future<AddressBook> _addressFuture;
  late PropertyType _type;
  late PlaceKind _placeKind;
  String? _placeName;
  String? _streetName;
  late final TextEditingController _buildingController;
  late final TextEditingController _blockController;
  late final TextEditingController _parcelController;
  late final TextEditingController _roomLayoutController;
  late final TextEditingController _squareMetersController;
  late final TextEditingController _costController;
  late final TextEditingController _saleController;
  late final TextEditingController _descriptionController;
  late List<String> _photoPaths;
  bool _saving = false;

  bool get _isEditing => widget.listing != null;

  @override
  void initState() {
    super.initState();
    final listing = widget.listing;
    _addressFuture = widget.addressRepository.load();
    _type = listing?.type ?? PropertyType.apartment;
    _placeKind = listing?.placeKind ?? PlaceKind.neighborhood;
    _placeName = listing?.placeName;
    _streetName = listing?.streetName;
    _buildingController = TextEditingController(text: listing?.buildingName);
    _blockController = TextEditingController(text: listing?.blockNo);
    _parcelController = TextEditingController(text: listing?.parcelNo);
    _roomLayoutController = TextEditingController(text: listing?.roomLayout);
    _squareMetersController = TextEditingController(
      text: listing?.squareMeters == null
          ? ''
          : listing!.squareMeters!.toStringAsFixed(
              listing.squareMeters! % 1 == 0 ? 0 : 1,
            ),
    );
    _costController = TextEditingController(
      text: listing == null ? '' : listing.costPrice.toStringAsFixed(0),
    );
    _saleController = TextEditingController(
      text: listing == null ? '' : listing.salePrice.toStringAsFixed(0),
    );
    _descriptionController = TextEditingController(
      text: listing?.description ?? '',
    );
    _photoPaths = [...?listing?.photoPaths];
    _costController.addListener(_recalculate);
    _saleController.addListener(_recalculate);
  }

  @override
  void dispose() {
    _buildingController.dispose();
    _blockController.dispose();
    _parcelController.dispose();
    _roomLayoutController.dispose();
    _squareMetersController.dispose();
    _costController.dispose();
    _saleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _recalculate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<AddressBook>(
      future: _addressFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final addressBook = snapshot.data;
        if (addressBook == null) {
          return const Center(child: Text('Adres verisi okunamadı.'));
        }
        return _buildForm(context, addressBook);
      },
    );

    if (!widget.standalone) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'İlan düzenle' : 'İlan ekle')),
      body: content,
    );
  }

  Widget _buildForm(BuildContext context, AddressBook addressBook) {
    final theme = Theme.of(context);
    final cost = parseMoneyInput(_costController.text);
    final sale = parseMoneyInput(_saleController.text);
    final profit = sale - cost;
    final profitPercent = cost <= 0 ? 0 : profit / cost * 100;
    final places = addressBook.placesFor(_placeKind);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calculate_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kar: ${formatMoney(profit)}  •  ${formatPercent(profitPercent)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SegmentedButton<PropertyType>(
            segments: PropertyType.values
                .map(
                  (type) => ButtonSegment<PropertyType>(
                    value: type,
                    icon: Icon(_iconForType(type)),
                    label: Text(type.label),
                  ),
                )
                .toList(),
            selected: {_type},
            onSelectionChanged: (value) {
              setState(() => _type = value.first);
            },
          ),
          const SizedBox(height: 16),
          SegmentedButton<PlaceKind>(
            segments: PlaceKind.values
                .map(
                  (kind) => ButtonSegment<PlaceKind>(
                    value: kind,
                    icon: Icon(
                      kind == PlaceKind.neighborhood
                          ? Icons.location_city_outlined
                          : Icons.forest_outlined,
                    ),
                    label: Text(kind.label),
                  ),
                )
                .toList(),
            selected: {_placeKind},
            onSelectionChanged: (value) {
              setState(() {
                _placeKind = value.first;
                _placeName = null;
                _streetName = null;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey('place-${_placeKind.name}-$_placeName'),
            initialValue: places.contains(_placeName) ? _placeName : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Mahalle/Köy',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            items: places
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            validator: (value) =>
                value == null ? 'Mahalle veya köy seçin.' : null,
            onChanged: (value) => setState(() => _placeName = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: ValueKey('street-$_streetName'),
            initialValue:
                addressBook.streets.contains(_streetName) ? _streetName : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _placeKind == PlaceKind.village
                  ? 'Cadde/Sokak/Yol (isteğe bağlı)'
                  : 'Cadde/Sokak/Yol',
              prefixIcon: const Icon(Icons.signpost_outlined),
            ),
            items: [
              if (_placeKind == PlaceKind.village)
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Seçilmedi'),
                ),
              ...addressBook.streets.map<DropdownMenuItem<String?>>(
                (item) => DropdownMenuItem(value: item, child: Text(item)),
              ),
            ],
            validator: (value) {
              if (_placeKind == PlaceKind.village) {
                return null;
              }
              return value == null ? 'Cadde, sokak veya yol seçin.' : null;
            },
            onChanged: (value) => setState(() => _streetName = value),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 230),
            child: _type == PropertyType.apartment
                ? Column(
                    key: const ValueKey('building'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _buildingController,
                        decoration: const InputDecoration(
                          labelText: 'Site veya bina adı',
                          prefixIcon: Icon(Icons.apartment_outlined),
                        ),
                        validator: (value) {
                          if (_type != PropertyType.apartment) {
                            return null;
                          }
                          return (value ?? '').trim().isEmpty
                              ? 'Site veya bina adını girin.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _roomLayoutController,
                              decoration: const InputDecoration(
                                labelText: 'Oda tipi',
                                hintText: '2+1',
                                prefixIcon: Icon(Icons.meeting_room_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _squareMetersController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Metrekare',
                                suffixText: 'm²',
                                prefixIcon: Icon(Icons.square_foot_outlined),
                              ),
                              validator: _optionalAreaValidator,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    key: const ValueKey('parcel'),
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _blockController,
                          decoration: const InputDecoration(
                            labelText: 'Ada',
                            prefixIcon: Icon(Icons.grid_view_outlined),
                          ),
                          validator: (value) {
                            if (_type == PropertyType.apartment) {
                              return null;
                            }
                            return (value ?? '').trim().isEmpty
                                ? 'Ada girin.'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _parcelController,
                          decoration: const InputDecoration(
                            labelText: 'Parsel',
                            prefixIcon: Icon(Icons.crop_square_outlined),
                          ),
                          validator: (value) {
                            if (_type == PropertyType.apartment) {
                              return null;
                            }
                            return (value ?? '').trim().isEmpty
                                ? 'Parsel girin.'
                                : null;
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _costController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Maliyet fiyatı',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  validator: _positiveMoneyValidator,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _saleController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Satış fiyatı',
                    prefixIcon: Icon(Icons.sell_outlined),
                  ),
                  validator: _positiveMoneyValidator,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Açıklama',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 18),
          _PhotoEditor(
            paths: _photoPaths,
            onPickGallery: _pickGallery,
            onTakePhoto: _takePhoto,
            onRemove: (path) => setState(() => _photoPaths.remove(path)),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isEditing ? 'Değişiklikleri kaydet' : 'İlanı kaydet'),
          ),
          if (_isEditing && widget.listing?.isSold == false) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving ? null : _showSoldDialog,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Satıldı olarak işaretle'),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconForType(PropertyType type) {
    switch (type) {
      case PropertyType.apartment:
        return Icons.apartment_outlined;
      case PropertyType.land:
        return Icons.terrain_outlined;
      case PropertyType.field:
        return Icons.agriculture_outlined;
    }
  }

  String? _positiveMoneyValidator(String? value) {
    return parseMoneyInput(value ?? '') <= 0 ? 'Geçerli fiyat girin.' : null;
  }

  String? _optionalAreaValidator(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    return parseOptionalNumberInput(raw) == null ? 'Geçerli m² girin.' : null;
  }

  Future<void> _pickGallery() async {
    try {
      final paths = await widget.photoService.pickFromGallery();
      if (!mounted) {
        return;
      }
      setState(() => _photoPaths.addAll(paths));
    } catch (error) {
      _showSnack('Fotoğraflar seçilemedi: $error');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final path = await widget.photoService.takePhoto();
      if (!mounted || path == null) {
        return;
      }
      setState(() => _photoPaths.add(path));
    } catch (error) {
      _showSnack('Kamera açılamadı: $error');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final previous = widget.listing;
      final listing = PropertyListing(
        id: previous?.id,
        type: _type,
        placeKind: _placeKind,
        placeName: _placeName!,
        streetName: _streetName ?? '',
        buildingName: _type == PropertyType.apartment
            ? _buildingController.text.trim()
            : null,
        blockNo: _type == PropertyType.apartment
            ? null
            : _blockController.text.trim(),
        parcelNo: _type == PropertyType.apartment
            ? null
            : _parcelController.text.trim(),
        roomLayout: _type == PropertyType.apartment
            ? _roomLayoutController.text.trim()
            : null,
        squareMeters: _type == PropertyType.apartment
            ? parseOptionalNumberInput(_squareMetersController.text)
            : null,
        costPrice: parseMoneyInput(_costController.text),
        salePrice: parseMoneyInput(_saleController.text),
        description: _descriptionController.text.trim(),
        photoPaths: _photoPaths,
        isSold: previous?.isSold ?? false,
        soldPrice: previous?.soldPrice,
        soldAt: previous?.soldAt,
        createdAt: previous?.createdAt ?? now,
        updatedAt: now,
      );

      if (previous == null) {
        await widget.database.insertListing(listing);
      } else {
        await widget.database.updateListing(listing);
      }

      if (!mounted) {
        return;
      }
      _showSnack('Kayıt tamamlandı.');
      if (widget.standalone) {
        widget.onSaved?.call();
        Navigator.of(context).pop(true);
      } else {
        widget.onSaved?.call();
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _showSoldDialog() async {
    final soldPrice = await showDialog<double>(
      context: context,
      builder: (context) =>
          _SoldPriceDialog(initialValue: _saleController.text),
    );

    final id = widget.listing?.id;
    if (soldPrice == null || id == null) {
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.database.markSold(listingId: id, soldPrice: soldPrice);
      if (!mounted) {
        return;
      }
      _showSnack('İlan satılanlara taşındı.');
      if (widget.standalone) {
        Navigator.of(context).pop(true);
      } else {
        widget.onSaved?.call();
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
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

class _SoldPriceDialog extends StatefulWidget {
  const _SoldPriceDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_SoldPriceDialog> createState() => _SoldPriceDialogState();
}

class _SoldPriceDialogState extends State<_SoldPriceDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Satış fiyatı'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Gerçek satış fiyatı',
          prefixIcon: Icon(Icons.payments_outlined),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Satıldı'),
        ),
      ],
    );
  }

  void _submit() {
    final value = parseMoneyInput(_controller.text);
    if (value > 0) {
      Navigator.of(context).pop(value);
    }
  }
}

class _PhotoEditor extends StatelessWidget {
  const _PhotoEditor({
    required this.paths,
    required this.onPickGallery,
    required this.onTakePhoto,
    required this.onRemove,
  });

  final List<String> paths;
  final VoidCallback onPickGallery;
  final VoidCallback onTakePhoto;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fotoğraflar',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: onPickGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Galeri'),
            ),
            const SizedBox(width: 10),
            FilledButton.tonalIcon(
              onPressed: onTakePhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Kamera'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (paths.isEmpty)
          Container(
            height: 104,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Henüz fotoğraf eklenmedi.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: paths.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final path = paths[index];
                final file = File(path);
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 126,
                        height: 112,
                        child: file.existsSync()
                            ? Image.file(file, fit: BoxFit.cover)
                            : ColoredBox(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton.filled(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Fotoğrafı kaldır',
                        onPressed: () => onRemove(path),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
