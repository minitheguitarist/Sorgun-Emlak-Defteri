import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../models/customer.dart';
import '../models/property_listing.dart';
import '../models/property_type.dart';
import '../services/address_repository.dart';
import '../services/app_database.dart';
import '../services/contact_picker_service.dart';
import '../services/formatters.dart';
import '../services/location_links.dart';
import '../services/photo_service.dart';
import '../services/reverse_geocoding_service.dart';
import '../widgets/search_selection_field.dart';
import 'location_picker_screen.dart';

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
  final _reverseGeocodingService = const ReverseGeocodingService();
  final _contactPickerService = const ContactPickerService();
  late Future<AddressBook> _addressFuture;
  late PropertyType? _type;
  late DealType? _dealType;
  late PlaceKind _placeKind;
  String? _placeName;
  String? _streetName;
  late final TextEditingController _buildingController;
  late final TextEditingController _blockController;
  late final TextEditingController _parcelController;
  late final TextEditingController _roomLayoutController;
  late final TextEditingController _squareMetersController;
  late final TextEditingController _buildingAgeController;
  late final TextEditingController _bathroomCountController;
  late final TextEditingController _balconyCountController;
  late final TextEditingController _floorCountController;
  late final TextEditingController _floorNumberController;
  late final TextEditingController _frontageController;
  late final TextEditingController _zoningStatusController;
  late final TextEditingController _roadFrontageController;
  late final TextEditingController _deedStatusController;
  late final TextEditingController _utilitiesController;
  late AreaUnit _landAreaUnit;
  late HousingKind? _housingKind;
  late final TextEditingController _ownerNameController;
  late final TextEditingController _ownerPhoneController;
  late final TextEditingController _costController;
  late final TextEditingController _saleController;
  late final TextEditingController _descriptionController;
  late List<String> _photoPaths;
  late Future<List<Customer>> _customersFuture;
  Set<int> _interestedCustomerIds = <int>{};
  double? _latitude;
  double? _longitude;
  bool _saving = false;
  bool _interestsLoaded = false;

  bool get _isEditing => widget.listing != null;

  bool get _showsFloorFields =>
      _type == PropertyType.apartment &&
      (_housingKind == HousingKind.apartment ||
          _housingKind == HousingKind.site);

  @override
  void initState() {
    super.initState();
    final listing = widget.listing;
    _addressFuture = widget.addressRepository.load();
    _type = listing?.type;
    _dealType = listing?.dealType;
    _placeKind = listing?.placeKind ?? PlaceKind.neighborhood;
    _placeName = listing?.placeName;
    _streetName = listing?.streetName;
    _buildingController = TextEditingController(text: listing?.buildingName);
    _blockController = TextEditingController(text: listing?.blockNo);
    _parcelController = TextEditingController(text: listing?.parcelNo);
    _roomLayoutController = TextEditingController(text: listing?.roomLayout);
    _landAreaUnit = listing?.areaUnit ?? AreaUnit.squareMeter;
    _squareMetersController = TextEditingController(
      text: listing?.squareMeters == null
          ? ''
          : _formatNumber(
              listing!.type == PropertyType.apartment
                  ? listing.squareMeters!
                  : _landAreaUnit.fromSquareMeters(listing.squareMeters!),
            ),
    );
    _buildingAgeController = TextEditingController(
      text: listing?.buildingAge?.toString() ?? '',
    );
    _bathroomCountController = TextEditingController(
      text: listing?.bathroomCount?.toString() ?? '',
    );
    _balconyCountController = TextEditingController(
      text: listing?.balconyCount?.toString() ?? '',
    );
    _floorCountController = TextEditingController(
      text: listing?.floorCount?.toString() ?? '',
    );
    _floorNumberController = TextEditingController(
      text: listing?.floorNumber?.toString() ?? '',
    );
    _frontageController = TextEditingController(text: listing?.frontage);
    _zoningStatusController =
        TextEditingController(text: listing?.zoningStatus);
    _roadFrontageController =
        TextEditingController(text: listing?.roadFrontage);
    _deedStatusController = TextEditingController(text: listing?.deedStatus);
    _utilitiesController = TextEditingController(text: listing?.utilities);
    _housingKind = listing?.housingKind;
    _ownerNameController = TextEditingController(text: listing?.ownerName);
    _ownerPhoneController = TextEditingController(
      text: listing == null ? '' : listing.ownerPhoneList.join('\n'),
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
    _latitude = listing?.latitude;
    _longitude = listing?.longitude;
    _customersFuture = widget.database.getCustomers();
    if (listing?.id != null) {
      _loadInterestedCustomers(listing!.id!);
    }
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
    _buildingAgeController.dispose();
    _bathroomCountController.dispose();
    _balconyCountController.dispose();
    _floorCountController.dispose();
    _floorNumberController.dispose();
    _frontageController.dispose();
    _zoningStatusController.dispose();
    _roadFrontageController.dispose();
    _deedStatusController.dispose();
    _utilitiesController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
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
    final profitPercent = sale <= 0 ? 0 : profit / sale * 100;
    final places = addressBook.placesFor(_placeKind);
    final priceLabel = _dealType?.priceLabel ?? 'Fiyat';

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
          SegmentedButton<DealType>(
            emptySelectionAllowed: true,
            segments: DealType.values
                .map(
                  (type) => ButtonSegment<DealType>(
                    value: type,
                    icon: Icon(
                      type == DealType.sale
                          ? Icons.sell_outlined
                          : Icons.vpn_key_outlined,
                    ),
                    label: Text(type.label),
                  ),
                )
                .toList(),
            selected: _dealType == null ? <DealType>{} : {_dealType!},
            onSelectionChanged: (value) {
              setState(() => _dealType = value.isEmpty ? null : value.first);
            },
          ),
          const SizedBox(height: 16),
          SegmentedButton<PropertyType>(
            emptySelectionAllowed: true,
            segments: PropertyType.values
                .map(
                  (type) => ButtonSegment<PropertyType>(
                    value: type,
                    icon: Icon(_iconForType(type)),
                    label: Text(type.label),
                  ),
                )
                .toList(),
            selected: _type == null ? <PropertyType>{} : {_type!},
            onSelectionChanged: (value) {
              setState(() => _type = value.isEmpty ? null : value.first);
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
          SearchSelectionField(
            label: 'Mahalle/Köy',
            value: places.contains(_placeName) ? _placeName : null,
            options: places,
            prefixIcon: Icons.place_outlined,
            requiredMessage: 'Mahalle veya köy seçin.',
            allowClear: false,
            onChanged: (value) => setState(() => _placeName = value),
          ),
          const SizedBox(height: 12),
          SearchSelectionField(
            label: 'Cadde/Sokak/Yol (isteğe bağlı)',
            value:
                addressBook.streets.contains(_streetName) ? _streetName : null,
            options: addressBook.streets,
            emptyText: 'Seçilmedi',
            prefixIcon: Icons.signpost_outlined,
            allowClear: true,
            clearText: 'Seçilmedi',
            onChanged: (value) => setState(() => _streetName = value),
          ),
          const SizedBox(height: 12),
          _LocationEditor(
            latitude: _latitude,
            longitude: _longitude,
            onSelect: _selectLocation,
            onSuggestAddress: _latitude == null || _longitude == null
                ? null
                : () => _suggestAddress(addressBook),
            onClear: _latitude == null || _longitude == null
                ? null
                : () => setState(() {
                      _latitude = null;
                      _longitude = null;
                    }),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 230),
            child: _type == null
                ? Container(
                    key: const ValueKey('type-empty'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: const Text(
                      'Daire, arsa veya tarla seçince ilgili alanlar burada görünecek.',
                    ),
                  )
                : _type == PropertyType.apartment
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
                                    prefixIcon:
                                        Icon(Icons.meeting_room_outlined),
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
                                    prefixIcon:
                                        Icon(Icons.square_foot_outlined),
                                  ),
                                  validator: _optionalAreaValidator,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _buildingAgeController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Bina yaşı',
                                    prefixIcon: Icon(Icons.history_outlined),
                                  ),
                                  validator: _optionalIntValidator,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _bathroomCountController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Banyo sayısı',
                                    prefixIcon: Icon(Icons.bathtub_outlined),
                                  ),
                                  validator: _optionalIntValidator,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _balconyCountController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Balkon sayısı',
                                    prefixIcon: Icon(Icons.balcony_outlined),
                                  ),
                                  validator: _optionalIntValidator,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<HousingKind>(
                                  initialValue: _housingKind,
                                  decoration: const InputDecoration(
                                    labelText: 'Konut tipi',
                                    prefixIcon: Icon(Icons.home_work_outlined),
                                  ),
                                  items: HousingKind.values
                                      .map(
                                        (kind) => DropdownMenuItem<HousingKind>(
                                          value: kind,
                                          child: Text(kind.label),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _housingKind = value;
                                      if (value == HousingKind.detached) {
                                        _floorCountController.clear();
                                        _floorNumberController.clear();
                                      }
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (_showsFloorFields) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _floorCountController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Toplam kat',
                                      prefixIcon: Icon(Icons.layers_outlined),
                                    ),
                                    validator: _optionalIntValidator,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _floorNumberController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Bulunduğu kat',
                                      prefixIcon: Icon(Icons.stairs_outlined),
                                    ),
                                    validator: _optionalIntValidator,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _frontageController,
                            decoration: const InputDecoration(
                              labelText: 'Cephe (isteğe bağlı)',
                              hintText: 'Güney, kuzey-doğu...',
                              prefixIcon: Icon(Icons.explore_outlined),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        key: const ValueKey('parcel'),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _blockController,
                                  decoration: const InputDecoration(
                                    labelText: 'Ada',
                                    prefixIcon: Icon(Icons.grid_view_outlined),
                                  ),
                                  validator: (value) {
                                    if (_type == null ||
                                        _type == PropertyType.apartment) {
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
                                    prefixIcon:
                                        Icon(Icons.crop_square_outlined),
                                  ),
                                  validator: (value) {
                                    if (_type == null ||
                                        _type == PropertyType.apartment) {
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
                          const SizedBox(height: 12),
                          SegmentedButton<AreaUnit>(
                            segments: AreaUnit.values
                                .map(
                                  (unit) => ButtonSegment<AreaUnit>(
                                    value: unit,
                                    label: Text(unit.label),
                                  ),
                                )
                                .toList(),
                            selected: {_landAreaUnit},
                            onSelectionChanged: (value) {
                              _changeLandAreaUnit(value.first);
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _squareMetersController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Alan',
                                    suffixText: _landAreaUnit.suffix,
                                    prefixIcon: const Icon(
                                      Icons.square_foot_outlined,
                                    ),
                                  ),
                                  validator: _areaValidator,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _zoningStatusController,
                                  decoration: const InputDecoration(
                                    labelText: 'İmar durumu',
                                    hintText: 'Tarla, konut, ticari...',
                                    prefixIcon: Icon(Icons.map_outlined),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _roadFrontageController,
                                  decoration: const InputDecoration(
                                    labelText: 'Yola cephe',
                                    hintText: 'Var, yok, metre...',
                                    prefixIcon: Icon(Icons.add_road_outlined),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _deedStatusController,
                                  decoration: const InputDecoration(
                                    labelText: 'Tapu durumu',
                                    hintText: 'Müstakil, hisseli...',
                                    prefixIcon:
                                        Icon(Icons.description_outlined),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _utilitiesController,
                            decoration: const InputDecoration(
                              labelText: 'Elektrik / Su',
                              hintText: 'Yakın, mevcut, yok...',
                              prefixIcon: Icon(Icons.water_drop_outlined),
                            ),
                          ),
                        ],
                      ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _pickOwnerFromContacts,
              icon: const Icon(Icons.contacts_outlined),
              label: const Text('Rehberden seç'),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ownerNameController,
            decoration: const InputDecoration(
              labelText: 'Mülk sahibi adı soyadı (isteğe bağlı)',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ownerPhoneController,
            keyboardType: TextInputType.phone,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Mülk sahibi telefonları (isteğe bağlı)',
              hintText: 'Her numarayı ayrı satıra yazabilirsiniz',
              prefixIcon: Icon(Icons.phone_outlined),
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
                  decoration: InputDecoration(
                    labelText: priceLabel,
                    prefixIcon: const Icon(Icons.sell_outlined),
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
          if (_isEditing) ...[
            const SizedBox(height: 20),
            _InterestedCustomersEditor(
              customersFuture: _customersFuture,
              selectedIds: _interestedCustomerIds,
              loaded: _interestsLoaded,
              onAdd: _addInterestedCustomer,
              onRemove: (id) {
                setState(() => _interestedCustomerIds.remove(id));
              },
            ),
          ],
          const SizedBox(height: 24),
          if (!(widget.listing?.isDeleted ?? false))
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label:
                  Text(_isEditing ? 'Değişiklikleri kaydet' : 'İlanı kaydet'),
            ),
          if (_isEditing &&
              widget.listing?.isSold == false &&
              widget.listing?.isDeleted == false) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving ? null : _showSoldDialog,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Satıldı olarak işaretle'),
            ),
          ],
          if (_isEditing &&
              widget.listing?.isSold == true &&
              widget.listing?.isDeleted == false) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving ? null : _reactivateListing,
              icon: const Icon(Icons.replay_outlined),
              label: const Text('Tekrar aktif satılığa al'),
            ),
          ],
          if (_isEditing && widget.listing?.isDeleted == false) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saving ? null : _confirmDeleteListing,
              icon: const Icon(Icons.delete_outline),
              label: const Text('İlanı sil'),
            ),
          ],
          if (_isEditing && widget.listing?.isDeleted == true) ...[
            OutlinedButton.icon(
              onPressed: _saving ? null : _restoreListing,
              icon: const Icon(Icons.restore_outlined),
              label: const Text('İlanı geri al'),
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

  String? _areaValidator(String? value) {
    final raw = (value ?? '').trim();
    if (_type != PropertyType.apartment && raw.isEmpty) {
      return 'Alan girin.';
    }
    if (raw.isEmpty) {
      return null;
    }
    return parseOptionalNumberInput(raw) == null ? 'Geçerli alan girin.' : null;
  }

  String? _optionalIntValidator(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(raw);
    return parsed == null || parsed < 0 ? 'Geçerli sayı girin.' : null;
  }

  int? _parseOptionalInt(String value) {
    final raw = value.trim();
    if (raw.isEmpty) {
      return null;
    }
    return int.tryParse(raw);
  }

  List<String> _parsePhoneList(String value) {
    final phones = <String>[];
    for (final part in value.split(RegExp(r'[\n,;]+'))) {
      final phone = part.trim();
      if (phone.isNotEmpty && !phones.contains(phone)) {
        phones.add(phone);
      }
    }
    return phones;
  }

  void _changeLandAreaUnit(AreaUnit unit) {
    if (unit == _landAreaUnit) {
      return;
    }
    final currentValue = parseOptionalNumberInput(_squareMetersController.text);
    setState(() {
      if (currentValue != null) {
        final squareMeters = _landAreaUnit.toSquareMeters(currentValue);
        _squareMetersController.text = _formatNumber(
          unit.fromSquareMeters(squareMeters),
        );
      }
      _landAreaUnit = unit;
    });
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

  Future<void> _pickOwnerFromContacts() async {
    try {
      final contact = await _contactPickerService.pickContact();
      if (!mounted || contact == null || contact.isEmpty) {
        return;
      }
      setState(() {
        if (contact.name.isNotEmpty) {
          _ownerNameController.text = contact.name;
        }
        if (contact.phones.isNotEmpty) {
          _ownerPhoneController.text = contact.phones.join('\n');
        }
      });
    } on PlatformException catch (error) {
      final message = error.code == 'permission_denied'
          ? 'Rehber izni verilmedi.'
          : 'Rehberden kişi seçilemedi.';
      _showSnack(message);
    } catch (error) {
      _showSnack('Rehberden kişi seçilemedi: $error');
    }
  }

  Future<void> _loadInterestedCustomers(int listingId) async {
    final ids = await widget.database.getInterestedCustomerIds(listingId);
    if (!mounted) {
      return;
    }
    setState(() {
      _interestedCustomerIds = ids.toSet();
      _interestsLoaded = true;
    });
  }

  Future<void> _addInterestedCustomer() async {
    final customers = await _customersFuture;
    if (!mounted) {
      return;
    }
    final available = customers
        .where((customer) =>
            customer.id != null &&
            !_interestedCustomerIds.contains(customer.id))
        .toList();
    if (available.isEmpty) {
      _showSnack('Eklenebilecek müşteri yok.');
      return;
    }

    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
                child: Text(
                  'İlgilenen müşteri ekle',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              for (final customer in available)
                ListTile(
                  leading: const Icon(Icons.person_add_alt_outlined),
                  title: Text(customer.fullName),
                  subtitle: customer.phone.trim().isEmpty
                      ? null
                      : Text(customer.phone),
                  onTap: () => Navigator.of(context).pop(customer.id),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() => _interestedCustomerIds.add(selected));
  }

  Future<void> _save() async {
    if (_dealType == null) {
      _showSnack('Satılık veya kiralık seçin.');
      return;
    }
    if (_type == null) {
      _showSnack('Daire, arsa veya tarla seçin.');
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final previous = widget.listing;
      final ownerPhones = _parsePhoneList(_ownerPhoneController.text);
      final hasFloorFields = _housingKind == HousingKind.apartment ||
          _housingKind == HousingKind.site;
      final frontage = _frontageController.text.trim();
      final listing = PropertyListing(
        id: previous?.id,
        type: _type!,
        dealType: _dealType,
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
            : _landAreaInputToSquareMeters(),
        areaUnit: _type == PropertyType.apartment ? null : _landAreaUnit,
        buildingAge: _type == PropertyType.apartment
            ? _parseOptionalInt(_buildingAgeController.text)
            : null,
        bathroomCount: _type == PropertyType.apartment
            ? _parseOptionalInt(_bathroomCountController.text)
            : null,
        balconyCount: _type == PropertyType.apartment
            ? _parseOptionalInt(_balconyCountController.text)
            : null,
        housingKind: _type == PropertyType.apartment ? _housingKind : null,
        floorCount: _type == PropertyType.apartment && hasFloorFields
            ? _parseOptionalInt(_floorCountController.text)
            : null,
        floorNumber: _type == PropertyType.apartment && hasFloorFields
            ? _parseOptionalInt(_floorNumberController.text)
            : null,
        frontage: _type == PropertyType.apartment && frontage.isNotEmpty
            ? frontage
            : null,
        zoningStatus: _type == PropertyType.apartment
            ? null
            : _emptyToNull(_zoningStatusController.text),
        roadFrontage: _type == PropertyType.apartment
            ? null
            : _emptyToNull(_roadFrontageController.text),
        deedStatus: _type == PropertyType.apartment
            ? null
            : _emptyToNull(_deedStatusController.text),
        utilities: _type == PropertyType.apartment
            ? null
            : _emptyToNull(_utilitiesController.text),
        latitude: _latitude,
        longitude: _longitude,
        ownerName: _ownerNameController.text.trim().isEmpty
            ? null
            : _ownerNameController.text.trim(),
        ownerPhone: ownerPhones.isEmpty ? null : ownerPhones.first,
        ownerPhones: ownerPhones,
        costPrice: parseMoneyInput(_costController.text),
        salePrice: parseMoneyInput(_saleController.text),
        description: _descriptionController.text.trim(),
        photoPaths: _photoPaths,
        isSold: previous?.isSold ?? false,
        soldPrice: previous?.soldPrice,
        soldAt: previous?.soldAt,
        soldCustomerId: previous?.soldCustomerId,
        isDeleted: previous?.isDeleted ?? false,
        deletedAt: previous?.deletedAt,
        createdAt: previous?.createdAt ?? now,
        updatedAt: now,
      );

      if (previous == null) {
        await widget.database.insertListing(listing);
      } else {
        await widget.database.updateListing(listing);
        final listingId = previous.id;
        if (listingId != null) {
          await widget.database.setListingInterests(
            listingId: listingId,
            customerIds: _interestedCustomerIds,
          );
        }
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
    final customers = await _customersFuture;
    if (!mounted) {
      return;
    }
    final result = await showDialog<_SoldListingResult>(
      context: context,
      builder: (context) => _SoldPriceDialog(
        initialValue: _saleController.text,
        customers: customers,
      ),
    );

    final id = widget.listing?.id;
    if (result == null || id == null) {
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.database.markSold(
        listingId: id,
        soldPrice: result.soldPrice,
        soldCustomerId: result.customerId,
      );
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

  Future<void> _reactivateListing() async {
    final id = widget.listing?.id;
    if (id == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tekrar aktif yapılsın mı?'),
        content: const Text(
          'İlan satılanlardan çıkar ve aktif ilanlar arasında görünür.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aktif yap'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.database.reactivateListing(id);
      if (!mounted) {
        return;
      }
      _showSnack('İlan tekrar aktif yapıldı.');
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

  Future<void> _confirmDeleteListing() async {
    final id = widget.listing?.id;
    if (id == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İlan silinsin mi?'),
        content: const Text(
          'İlan çöp kutusuna taşınır. Düzenleme ekranındaki Silinenler sekmesinden geri alınabilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.database.softDeleteListing(id);
      if (!mounted) {
        return;
      }
      _showSnack('İlan silinenlere taşındı.');
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

  Future<void> _restoreListing() async {
    final id = widget.listing?.id;
    if (id == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.database.restoreListing(id);
      if (!mounted) {
        return;
      }
      _showSnack('İlan geri alındı.');
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

  Future<void> _selectLocation() async {
    final selected = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _latitude = selected.latitude;
      _longitude = selected.longitude;
    });
  }

  Future<void> _suggestAddress(AddressBook addressBook) async {
    final latitude = _latitude;
    final longitude = _longitude;
    if (latitude == null || longitude == null) {
      return;
    }

    _showSnack('Konumdan adres aranıyor.');
    try {
      final suggestion = await _reverseGeocodingService.suggestAddress(
        latitude: latitude,
        longitude: longitude,
        addressBook: addressBook,
      );
      if (!mounted) {
        return;
      }
      final result = await showDialog<_AddressSelectionResult>(
        context: context,
        builder: (context) => _AddressSuggestionDialog(
          addressBook: addressBook,
          suggestion: suggestion,
          currentPlaceKind: _placeKind,
          currentPlaceName: _placeName,
          currentStreetName: _streetName,
        ),
      );
      if (!mounted || result == null) {
        return;
      }
      setState(() {
        _placeKind = result.placeKind;
        _placeName = result.placeName;
        _streetName = result.streetName;
      });
    } catch (error) {
      _showSnack('Adres önerilemedi: $error');
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

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _landAreaInputToSquareMeters() {
    final value = parseOptionalNumberInput(_squareMetersController.text);
    if (value == null) {
      return null;
    }
    return _landAreaUnit.toSquareMeters(value);
  }

  static String _formatNumber(num value) {
    final decimalDigits = value % 1 == 0 ? 0 : 2;
    return value.toStringAsFixed(decimalDigits);
  }
}

class _LocationEditor extends StatelessWidget {
  const _LocationEditor({
    required this.latitude,
    required this.longitude,
    required this.onSelect,
    required this.onSuggestAddress,
    required this.onClear,
  });

  final double? latitude;
  final double? longitude;
  final VoidCallback onSelect;
  final VoidCallback? onSuggestAddress;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLocation = latitude != null && longitude != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasLocation
                      ? formatCoordinates(
                          latitude: latitude!,
                          longitude: longitude!,
                        )
                      : 'Konum seçilmedi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: onSelect,
                  icon: const Icon(Icons.map_outlined),
                  label: Text(hasLocation ? 'Konumu değiştir' : 'Konum seç'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Konumu temizle',
                onPressed: onClear,
                icon: const Icon(Icons.location_off_outlined),
              ),
            ],
          ),
          if (hasLocation) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSuggestAddress,
                icon: const Icon(Icons.manage_search_outlined),
                label: const Text('Konumdan adres öner'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddressSelectionResult {
  const _AddressSelectionResult({
    required this.placeKind,
    required this.placeName,
    required this.streetName,
  });

  final PlaceKind placeKind;
  final String placeName;
  final String? streetName;
}

class _AddressSuggestionDialog extends StatefulWidget {
  const _AddressSuggestionDialog({
    required this.addressBook,
    required this.suggestion,
    required this.currentPlaceKind,
    required this.currentPlaceName,
    required this.currentStreetName,
  });

  final AddressBook addressBook;
  final AddressSuggestion suggestion;
  final PlaceKind currentPlaceKind;
  final String? currentPlaceName;
  final String? currentStreetName;

  @override
  State<_AddressSuggestionDialog> createState() =>
      _AddressSuggestionDialogState();
}

class _AddressSuggestionDialogState extends State<_AddressSuggestionDialog> {
  late PlaceKind _placeKind;
  late String? _placeName;
  late String? _streetName;

  @override
  void initState() {
    super.initState();
    _placeKind = widget.suggestion.placeKind;
    _placeName = widget.suggestion.placeName ?? widget.currentPlaceName;
    _streetName = widget.suggestion.streetName ?? widget.currentStreetName;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final places = widget.addressBook.placesFor(_placeKind);
    return AlertDialog(
      title: const Text('Adres önerisi'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Konumdan bulunan adresi kontrol edin. Yanlışsa listeden düzeltebilirsiniz.',
              style: theme.textTheme.bodyMedium,
            ),
            if (widget.suggestion.rawAddress.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                widget.suggestion.rawAddress,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SegmentedButton<PlaceKind>(
              segments: PlaceKind.values
                  .map(
                    (kind) => ButtonSegment<PlaceKind>(
                      value: kind,
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
            const SizedBox(height: 12),
            SearchSelectionField(
              label: 'Mahalle/Köy',
              value: places.contains(_placeName) ? _placeName : null,
              options: places,
              allowClear: false,
              onChanged: (value) => setState(() => _placeName = value),
            ),
            const SizedBox(height: 12),
            SearchSelectionField(
              label: 'Cadde/Sokak/Yol (isteğe bağlı)',
              value: widget.addressBook.streets.contains(_streetName)
                  ? _streetName
                  : null,
              options: widget.addressBook.streets,
              allowClear: true,
              clearText: 'Seçilmedi',
              onChanged: (value) => setState(() => _streetName = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _placeName == null
              ? null
              : () => Navigator.of(context).pop(
                    _AddressSelectionResult(
                      placeKind: _placeKind,
                      placeName: _placeName!,
                      streetName: _streetName,
                    ),
                  ),
          child: const Text('Kullan'),
        ),
      ],
    );
  }
}

class _SoldListingResult {
  const _SoldListingResult({
    required this.soldPrice,
    required this.customerId,
  });

  final double soldPrice;
  final int? customerId;
}

class _SoldPriceDialog extends StatefulWidget {
  const _SoldPriceDialog({
    required this.initialValue,
    required this.customers,
  });

  final String initialValue;
  final List<Customer> customers;

  @override
  State<_SoldPriceDialog> createState() => _SoldPriceDialogState();
}

class _SoldPriceDialogState extends State<_SoldPriceDialog> {
  late final TextEditingController _controller;
  int? _customerId;

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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Gerçek satış fiyatı',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _customerId,
            decoration: const InputDecoration(
              labelText: 'Kime satıldı? (opsiyonel)',
              prefixIcon: Icon(Icons.person_outline),
            ),
            items: [
              const DropdownMenuItem<int>(
                child: Text('Müşteri seçme'),
              ),
              ...widget.customers.where((customer) => customer.id != null).map(
                    (customer) => DropdownMenuItem<int>(
                      value: customer.id,
                      child: Text(customer.fullName),
                    ),
                  ),
            ],
            onChanged: (value) => setState(() => _customerId = value),
          ),
        ],
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
      Navigator.of(context).pop(
        _SoldListingResult(soldPrice: value, customerId: _customerId),
      );
    }
  }
}

class _InterestedCustomersEditor extends StatelessWidget {
  const _InterestedCustomersEditor({
    required this.customersFuture,
    required this.selectedIds,
    required this.loaded,
    required this.onAdd,
    required this.onRemove,
  });

  final Future<List<Customer>> customersFuture;
  final Set<int> selectedIds;
  final bool loaded;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<Customer>>(
      future: customersFuture,
      builder: (context, snapshot) {
        final customers = snapshot.data ?? const [];
        final selected = customers
            .where((customer) =>
                customer.id != null && selectedIds.contains(customer.id))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'İlgilenen müşteriler',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: snapshot.connectionState == ConnectionState.waiting
                      ? null
                      : onAdd,
                  icon: const Icon(Icons.person_add_alt_outlined),
                  label: const Text('Ekle'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!loaded || snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator()
            else if (customers.isEmpty)
              Text(
                'Önce Müşteriler bölümünden müşteri kaydı ekleyin.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else if (selected.isEmpty)
              Text(
                'Bu ilanla ilgilenen müşteri eklenmedi.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final customer in selected)
                    InputChip(
                      avatar: const Icon(Icons.person_outline, size: 18),
                      label: Text(customer.fullName),
                      onDeleted: () => onRemove(customer.id!),
                    ),
                ],
              ),
          ],
        );
      },
    );
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
