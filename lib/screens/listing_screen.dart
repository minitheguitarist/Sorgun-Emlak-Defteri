import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/property_listing.dart';
import '../models/property_type.dart';
import '../services/address_repository.dart';
import '../services/app_database.dart';
import '../services/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/listing_card.dart';
import '../widgets/search_selection_field.dart';
import 'property_detail_screen.dart';

enum _ListingsView {
  list,
  map;

  String get label {
    switch (this) {
      case _ListingsView.list:
        return 'Liste';
      case _ListingsView.map:
        return 'Harita';
    }
  }
}

class ListingScreen extends StatefulWidget {
  const ListingScreen({
    super.key,
    required this.database,
    required this.addressRepository,
    required this.refreshNonce,
  });

  final AppDatabase database;
  final AddressRepository addressRepository;
  final int refreshNonce;

  @override
  State<ListingScreen> createState() => _ListingScreenState();
}

class _ListingScreenState extends State<ListingScreen> {
  late Future<AddressBook> _addressFuture;
  late Future<List<PropertyListing>> _listingsFuture;
  _ListingsView _view = _ListingsView.list;
  DealType? _dealType;
  PropertyType? _type;
  PlaceKind? _placeKind;
  String? _placeName;
  String? _streetName;
  HousingKind? _housingKind;
  final _blockController = TextEditingController();
  final _parcelController = TextEditingController();
  final _roomLayoutController = TextEditingController();
  final _minSquareMetersController = TextEditingController();
  final _maxSquareMetersController = TextEditingController();
  final _maxBuildingAgeController = TextEditingController();
  final _minBathroomController = TextEditingController();
  final _minBalconyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _addressFuture = widget.addressRepository.load();
    _listingsFuture = widget.database.getActiveListings();
  }

  @override
  void didUpdateWidget(covariant ListingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshNonce != widget.refreshNonce) {
      _refresh();
    }
  }

  @override
  void dispose() {
    _blockController.dispose();
    _parcelController.dispose();
    _roomLayoutController.dispose();
    _minSquareMetersController.dispose();
    _maxSquareMetersController.dispose();
    _maxBuildingAgeController.dispose();
    _minBathroomController.dispose();
    _minBalconyController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _listingsFuture = widget.database.getActiveListings();
    });
    await _listingsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AddressBook>(
      future: _addressFuture,
      builder: (context, addressSnapshot) {
        final addressBook = addressSnapshot.data;
        return Column(
          children: [
            _ListingToolbar(
              view: _view,
              activeFilterCount: _activeFilterCount,
              onViewChanged: (view) => setState(() => _view = view),
              onFilterPressed: () => _showFilters(addressBook),
            ),
            Expanded(
              child: FutureBuilder<List<PropertyListing>>(
                future: _listingsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allListings = snapshot.data ?? const [];
                  final listings = _applyFilters(allListings);
                  if (allListings.isEmpty) {
                    return const EmptyState(
                      icon: Icons.real_estate_agent_outlined,
                      title: 'Aktif ilan yok',
                      message:
                          'Ekleme ekranından daire, arsa veya tarla kaydı oluşturabilirsiniz.',
                    );
                  }
                  if (listings.isEmpty) {
                    return EmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'Filtreye uyan ilan yok',
                      message:
                          'Filtreleri temizleyerek aktif ilanları yeniden görebilirsiniz.',
                      action: FilledButton.tonalIcon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Filtreleri temizle'),
                      ),
                    );
                  }

                  if (_view == _ListingsView.map) {
                    return _ListingMapView(
                      listings: listings,
                      database: widget.database,
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: listings.length,
                      itemBuilder: (context, index) {
                        final listing = listings[index];
                        return AnimatedPadding(
                          duration: Duration(milliseconds: 150 + index * 18),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.zero,
                          child: ListingCard(
                            listing: listing,
                            onTap: () => _openListing(listing),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _openListing(PropertyListing listing) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PropertyDetailScreen(
          database: widget.database,
          listing: listing,
        ),
      ),
    );
  }

  List<PropertyListing> _applyFilters(List<PropertyListing> listings) {
    final block = _blockController.text.trim().toLowerCase();
    final parcel = _parcelController.text.trim().toLowerCase();
    final roomLayout = _roomLayoutController.text.trim().toLowerCase();
    final minSquareMeters =
        parseOptionalNumberInput(_minSquareMetersController.text);
    final maxSquareMeters =
        parseOptionalNumberInput(_maxSquareMetersController.text);
    final maxBuildingAge = _parseOptionalInt(_maxBuildingAgeController.text);
    final minBathroomCount = _parseOptionalInt(_minBathroomController.text);
    final minBalconyCount = _parseOptionalInt(_minBalconyController.text);

    return listings.where((listing) {
      if (_dealType != null && listing.dealType != _dealType) {
        return false;
      }
      if (_type != null && listing.type != _type) {
        return false;
      }
      if (_placeKind != null && listing.placeKind != _placeKind) {
        return false;
      }
      if (_placeName != null && listing.placeName != _placeName) {
        return false;
      }
      if (_streetName != null && listing.streetName != _streetName) {
        return false;
      }
      if (_housingKind != null && listing.housingKind != _housingKind) {
        return false;
      }
      if (block.isNotEmpty &&
          !(listing.blockNo ?? '').toLowerCase().contains(block)) {
        return false;
      }
      if (parcel.isNotEmpty &&
          !(listing.parcelNo ?? '').toLowerCase().contains(parcel)) {
        return false;
      }
      if (roomLayout.isNotEmpty &&
          !(listing.roomLayout ?? '').toLowerCase().contains(roomLayout)) {
        return false;
      }
      if (minSquareMeters != null &&
          ((listing.squareMeters ?? 0) < minSquareMeters)) {
        return false;
      }
      if (maxSquareMeters != null &&
          ((listing.squareMeters ?? double.infinity) > maxSquareMeters)) {
        return false;
      }
      if (maxBuildingAge != null &&
          ((listing.buildingAge ?? double.infinity) > maxBuildingAge)) {
        return false;
      }
      if (minBathroomCount != null &&
          ((listing.bathroomCount ?? 0) < minBathroomCount)) {
        return false;
      }
      if (minBalconyCount != null &&
          ((listing.balconyCount ?? 0) < minBalconyCount)) {
        return false;
      }
      return true;
    }).toList();
  }

  int get _activeFilterCount {
    var count = 0;
    if (_dealType != null) count++;
    if (_type != null) count++;
    if (_placeKind != null) count++;
    if (_placeName != null) count++;
    if (_streetName != null) count++;
    if (_housingKind != null) count++;
    for (final controller in [
      _blockController,
      _parcelController,
      _roomLayoutController,
      _minSquareMetersController,
      _maxSquareMetersController,
      _maxBuildingAgeController,
      _minBathroomController,
      _minBalconyController,
    ]) {
      if (controller.text.trim().isNotEmpty) {
        count++;
      }
    }
    return count;
  }

  void _clearFilters() {
    setState(() {
      _dealType = null;
      _type = null;
      _placeKind = null;
      _placeName = null;
      _streetName = null;
      _housingKind = null;
      _blockController.clear();
      _parcelController.clear();
      _roomLayoutController.clear();
      _minSquareMetersController.clear();
      _maxSquareMetersController.clear();
      _maxBuildingAgeController.clear();
      _minBathroomController.clear();
      _minBalconyController.clear();
    });
  }

  Future<void> _showFilters(AddressBook? addressBook) async {
    if (addressBook == null) {
      return;
    }

    var dealType = _dealType;
    var type = _type;
    var placeKind = _placeKind;
    var placeName = _placeName;
    var streetName = _streetName;
    var housingKind = _housingKind;
    final blockController = TextEditingController(text: _blockController.text);
    final parcelController =
        TextEditingController(text: _parcelController.text);
    final roomLayoutController =
        TextEditingController(text: _roomLayoutController.text);
    final minSquareMetersController =
        TextEditingController(text: _minSquareMetersController.text);
    final maxSquareMetersController =
        TextEditingController(text: _maxSquareMetersController.text);
    final maxBuildingAgeController =
        TextEditingController(text: _maxBuildingAgeController.text);
    final minBathroomController =
        TextEditingController(text: _minBathroomController.text);
    final minBalconyController =
        TextEditingController(text: _minBalconyController.text);

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final places = placeKind == null
                ? [
                    ...addressBook.neighborhoods,
                    ...addressBook.villages,
                  ]
                : addressBook.placesFor(placeKind!);
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  8,
                  18,
                  MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Filtrele',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 14),
                      _FilterSegment<DealType>(
                        label: 'Satılık / Kiralık',
                        values: DealType.values,
                        selected: dealType,
                        labelFor: (value) => value.label,
                        onChanged: (value) {
                          setSheetState(() => dealType = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      _FilterSegment<PropertyType>(
                        label: 'Mülk tipi',
                        values: PropertyType.values,
                        selected: type,
                        labelFor: (value) => value.label,
                        onChanged: (value) {
                          setSheetState(() {
                            type = value;
                            if (type == PropertyType.apartment) {
                              blockController.clear();
                              parcelController.clear();
                            } else {
                              roomLayoutController.clear();
                              minSquareMetersController.clear();
                              maxSquareMetersController.clear();
                              maxBuildingAgeController.clear();
                              minBathroomController.clear();
                              minBalconyController.clear();
                              housingKind = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      _FilterSegment<PlaceKind>(
                        label: 'Yer türü',
                        values: PlaceKind.values,
                        selected: placeKind,
                        labelFor: (value) => value.label,
                        onChanged: (value) {
                          setSheetState(() {
                            placeKind = value;
                            placeName = null;
                            streetName = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      SearchSelectionField(
                        label: 'Mahalle/Köy',
                        value: places.contains(placeName) ? placeName : null,
                        options: places,
                        emptyText: 'Hepsi',
                        clearText: 'Hepsi',
                        onChanged: (value) {
                          setSheetState(() => placeName = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      SearchSelectionField(
                        label: 'Cadde/Sokak/Yol',
                        value: addressBook.streets.contains(streetName)
                            ? streetName
                            : null,
                        options: addressBook.streets,
                        emptyText: 'Hepsi',
                        clearText: 'Hepsi',
                        onChanged: (value) {
                          setSheetState(() => streetName = value);
                        },
                      ),
                      if (type == PropertyType.apartment) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: roomLayoutController,
                          decoration: const InputDecoration(
                            labelText: 'Oda tipi',
                            hintText: '2+1',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minSquareMetersController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Min m²',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: maxSquareMetersController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Max m²',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: maxBuildingAgeController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Max bina yaşı',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: minBathroomController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Min banyo',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minBalconyController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Min balkon',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<HousingKind>(
                                initialValue: housingKind,
                                decoration: const InputDecoration(
                                  labelText: 'Konut tipi',
                                ),
                                items: [
                                  const DropdownMenuItem<HousingKind>(
                                    value: null,
                                    child: Text('Hepsi'),
                                  ),
                                  ...HousingKind.values.map(
                                    (kind) => DropdownMenuItem<HousingKind>(
                                      value: kind,
                                      child: Text(kind.label),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setSheetState(() => housingKind = value);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (type == PropertyType.land ||
                          type == PropertyType.field) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: blockController,
                                decoration: const InputDecoration(
                                  labelText: 'Ada',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: parcelController,
                                decoration: const InputDecoration(
                                  labelText: 'Parsel',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setSheetState(() {
                                  dealType = null;
                                  type = null;
                                  placeKind = null;
                                  placeName = null;
                                  streetName = null;
                                  housingKind = null;
                                  blockController.clear();
                                  parcelController.clear();
                                  roomLayoutController.clear();
                                  minSquareMetersController.clear();
                                  maxSquareMetersController.clear();
                                  maxBuildingAgeController.clear();
                                  minBathroomController.clear();
                                  minBalconyController.clear();
                                });
                              },
                              icon: const Icon(Icons.filter_alt_off_outlined),
                              label: const Text('Temizle'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => Navigator.of(context).pop(true),
                              icon: const Icon(Icons.check),
                              label: const Text('Uygula'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (applied == true && mounted) {
      setState(() {
        _dealType = dealType;
        _type = type;
        _placeKind = placeKind;
        _placeName = placeName;
        _streetName = streetName;
        _housingKind = housingKind;
        _blockController.text = blockController.text;
        _parcelController.text = parcelController.text;
        _roomLayoutController.text = roomLayoutController.text;
        _minSquareMetersController.text = minSquareMetersController.text;
        _maxSquareMetersController.text = maxSquareMetersController.text;
        _maxBuildingAgeController.text = maxBuildingAgeController.text;
        _minBathroomController.text = minBathroomController.text;
        _minBalconyController.text = minBalconyController.text;
      });
    }

    blockController.dispose();
    parcelController.dispose();
    roomLayoutController.dispose();
    minSquareMetersController.dispose();
    maxSquareMetersController.dispose();
    maxBuildingAgeController.dispose();
    minBathroomController.dispose();
    minBalconyController.dispose();
  }

  int? _parseOptionalInt(String value) {
    final raw = value.trim();
    if (raw.isEmpty) {
      return null;
    }
    return int.tryParse(raw);
  }
}

class _ListingToolbar extends StatelessWidget {
  const _ListingToolbar({
    required this.view,
    required this.activeFilterCount,
    required this.onViewChanged,
    required this.onFilterPressed,
  });

  final _ListingsView view;
  final int activeFilterCount;
  final ValueChanged<_ListingsView> onViewChanged;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: SegmentedButton<_ListingsView>(
                segments: _ListingsView.values
                    .map(
                      (view) => ButtonSegment<_ListingsView>(
                        value: view,
                        icon: Icon(
                          view == _ListingsView.list
                              ? Icons.view_list_outlined
                              : Icons.map_outlined,
                        ),
                        label: Text(view.label),
                      ),
                    )
                    .toList(),
                selected: {view},
                onSelectionChanged: (value) => onViewChanged(value.first),
              ),
            ),
            const SizedBox(width: 10),
            Badge.count(
              count: activeFilterCount,
              isLabelVisible: activeFilterCount > 0,
              child: IconButton.filledTonal(
                tooltip: 'Filtrele',
                onPressed: onFilterPressed,
                icon: const Icon(Icons.tune_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSegment<T> extends StatelessWidget {
  const _FilterSegment({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final List<T> values;
  final T? selected;
  final String Function(T value) labelFor;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        SegmentedButton<T>(
          emptySelectionAllowed: true,
          segments: values
              .map(
                (value) => ButtonSegment<T>(
                  value: value,
                  label: Text(labelFor(value)),
                ),
              )
              .toList(),
          selected: selected == null ? <T>{} : {selected as T},
          onSelectionChanged: (value) {
            onChanged(value.isEmpty ? null : value.first);
          },
        ),
      ],
    );
  }
}

class _ListingMapView extends StatefulWidget {
  const _ListingMapView({
    required this.listings,
    required this.database,
  });

  final List<PropertyListing> listings;
  final AppDatabase database;

  @override
  State<_ListingMapView> createState() => _ListingMapViewState();
}

class _ListingMapViewState extends State<_ListingMapView> {
  bool _tileError = false;
  int _mapNonce = 0;

  @override
  Widget build(BuildContext context) {
    final locatedListings =
        widget.listings.where((listing) => listing.hasLocation).toList();
    if (locatedListings.isEmpty) {
      return const EmptyState(
        icon: Icons.location_off_outlined,
        title: 'Konumlu ilan yok',
        message:
            'Haritada görmek için ilanlara ekleme veya düzenleme ekranından konum seçin.',
      );
    }

    final center = LatLng(
      locatedListings.first.latitude!,
      locatedListings.first.longitude!,
    );
    return Stack(
      children: [
        FlutterMap(
          key: ValueKey(_mapNonce),
          options: MapOptions(
            initialCenter: center,
            initialZoom: locatedListings.length == 1 ? 16 : 13,
            minZoom: 6,
            maxZoom: 19,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.sorgunemlak.defter',
              errorTileCallback: (_, __, ___) {
                if (!_tileError && mounted) {
                  setState(() => _tileError = true);
                }
              },
            ),
            MarkerLayer(
              markers: locatedListings.map((listing) {
                return Marker(
                  point: LatLng(listing.latitude!, listing.longitude!),
                  width: 48,
                  height: 48,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () => _showListingPreview(listing),
                    child: Icon(
                      Icons.location_pin,
                      size: 46,
                      color: _colorForType(listing.type),
                    ),
                  ),
                );
              }).toList(),
            ),
            SimpleAttributionWidget(
              source: const Text('OpenStreetMap contributors'),
              backgroundColor:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
            ),
          ],
        ),
        if (_tileError)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Card(
                margin: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_outlined),
                      const SizedBox(width: 8),
                      const Flexible(
                        child:
                            Text('Harita yüklenemedi. İnterneti kontrol edin.'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _tileError = false;
                            _mapNonce++;
                          });
                        },
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showListingPreview(PropertyListing listing) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ListingCard(
            listing: listing,
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => PropertyDetailScreen(
                    database: widget.database,
                    listing: listing,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Color _colorForType(PropertyType type) {
    switch (type) {
      case PropertyType.apartment:
        return const Color(0xFF156C5B);
      case PropertyType.land:
        return const Color(0xFF8A5A18);
      case PropertyType.field:
        return const Color(0xFF407A36);
    }
  }
}
