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
  late Future<_ListingsData> _listingsFuture;
  _ListingsView _view = _ListingsView.list;
  bool _searchOpen = false;
  DealType? _dealType;
  PropertyType? _type;
  PlaceKind? _placeKind;
  String? _placeName;
  String? _streetName;
  HousingKind? _housingKind;
  AreaUnit _areaFilterUnit = AreaUnit.squareMeter;
  final _searchController = TextEditingController();
  final _blockController = TextEditingController();
  final _parcelController = TextEditingController();
  final _roomLayoutController = TextEditingController();
  final _minSquareMetersController = TextEditingController();
  final _maxSquareMetersController = TextEditingController();
  final _maxBuildingAgeController = TextEditingController();
  final _minBathroomController = TextEditingController();
  final _minBalconyController = TextEditingController();
  final _floorCountController = TextEditingController();
  final _floorNumberController = TextEditingController();
  final _frontageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _addressFuture = widget.addressRepository.load();
    _listingsFuture = _loadListings();
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
    _searchController.dispose();
    _blockController.dispose();
    _parcelController.dispose();
    _roomLayoutController.dispose();
    _minSquareMetersController.dispose();
    _maxSquareMetersController.dispose();
    _maxBuildingAgeController.dispose();
    _minBathroomController.dispose();
    _minBalconyController.dispose();
    _floorCountController.dispose();
    _floorNumberController.dispose();
    _frontageController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _listingsFuture = _loadListings();
    });
    await _listingsFuture;
  }

  Future<_ListingsData> _loadListings() async {
    final listings = await widget.database.getActiveListings();
    final interestCounts = await widget.database.getListingInterestCounts();
    return _ListingsData(listings: listings, interestCounts: interestCounts);
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
              searchOpen: _searchOpen,
              searchController: _searchController,
              activeFilterCount: _activeFilterCount,
              onViewChanged: (view) => setState(() => _view = view),
              onSearchChanged: (_) => setState(() {}),
              onSearchToggle: () {
                setState(() {
                  if (_searchOpen && _searchController.text.isNotEmpty) {
                    _searchController.clear();
                  } else {
                    _searchOpen = !_searchOpen;
                  }
                });
              },
              onFilterPressed: () => _showFilters(addressBook),
            ),
            Expanded(
              child: FutureBuilder<_ListingsData>(
                future: _listingsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data ?? const _ListingsData();
                  final allListings = data.listings;
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
                            interestCount: data.interestCounts[listing.id] ?? 0,
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
    final searchQuery = _searchController.text;
    final block = _blockController.text.trim().toLowerCase();
    final parcel = _parcelController.text.trim().toLowerCase();
    final roomLayout = _roomLayoutController.text.trim().toLowerCase();
    final frontage = _frontageController.text;
    final minSquareMeters = _parseFilterArea(_minSquareMetersController.text);
    final maxSquareMeters = _parseFilterArea(_maxSquareMetersController.text);
    final maxBuildingAge = _parseOptionalInt(_maxBuildingAgeController.text);
    final minBathroomCount = _parseOptionalInt(_minBathroomController.text);
    final minBalconyCount = _parseOptionalInt(_minBalconyController.text);
    final floorCount = _parseOptionalInt(_floorCountController.text);
    final floorNumber = _parseOptionalInt(_floorNumberController.text);

    return listings.where((listing) {
      if (!_matchesGeneralSearch(listing, searchQuery)) {
        return false;
      }
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
      if (floorCount != null && listing.floorCount != floorCount) {
        return false;
      }
      if (floorNumber != null && listing.floorNumber != floorNumber) {
        return false;
      }
      if (frontage.trim().isNotEmpty &&
          !_normalizedContains(listing.frontage ?? '', frontage)) {
        return false;
      }
      return true;
    }).toList();
  }

  bool _matchesGeneralSearch(PropertyListing listing, String query) {
    if (query.trim().isEmpty) {
      return true;
    }
    final haystack = [
      listing.displayTitle,
      listing.buildingName,
      listing.description,
      listing.placeName,
      listing.streetName,
      listing.blockNo,
      listing.parcelNo,
      listing.roomLayout,
      listing.frontage,
      listing.housingKind?.label,
      listing.ownerName,
      ...listing.ownerPhoneList,
    ].whereType<String>().join(' ');
    return _normalizedContains(haystack, query);
  }

  bool _normalizedContains(String value, String query) {
    final normalizedValue = _normalizeSearchText(value);
    final normalizedQuery = _normalizeSearchText(query);
    if (normalizedQuery.isEmpty) {
      return true;
    }
    if (normalizedValue.contains(normalizedQuery)) {
      return true;
    }
    return normalizedValue.replaceAll(' ', '').contains(
          normalizedQuery.replaceAll(' ', ''),
        );
  }

  String _normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll('\u0307', '')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
      _floorCountController,
      _floorNumberController,
      _frontageController,
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
      _areaFilterUnit = AreaUnit.squareMeter;
      _searchController.clear();
      _searchOpen = false;
      _blockController.clear();
      _parcelController.clear();
      _roomLayoutController.clear();
      _minSquareMetersController.clear();
      _maxSquareMetersController.clear();
      _maxBuildingAgeController.clear();
      _minBathroomController.clear();
      _minBalconyController.clear();
      _floorCountController.clear();
      _floorNumberController.clear();
      _frontageController.clear();
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
    var areaFilterUnit = _areaFilterUnit;
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
    final floorCountController =
        TextEditingController(text: _floorCountController.text);
    final floorNumberController =
        TextEditingController(text: _floorNumberController.text);
    final frontageController =
        TextEditingController(text: _frontageController.text);

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
                              areaFilterUnit = AreaUnit.squareMeter;
                            } else {
                              roomLayoutController.clear();
                              maxBuildingAgeController.clear();
                              minBathroomController.clear();
                              minBalconyController.clear();
                              floorCountController.clear();
                              floorNumberController.clear();
                              frontageController.clear();
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
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: floorCountController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Toplam kat',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: floorNumberController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Bulunduğu kat',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: frontageController,
                          decoration: const InputDecoration(
                            labelText: 'Cephe',
                            hintText: 'Güney, kuzey-doğu...',
                          ),
                        ),
                      ],
                      if (type == PropertyType.land ||
                          type == PropertyType.field) ...[
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
                          selected: {areaFilterUnit},
                          onSelectionChanged: (value) {
                            setSheetState(() => areaFilterUnit = value.first);
                          },
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
                                decoration: InputDecoration(
                                  labelText:
                                      'Min alan (${areaFilterUnit.suffix})',
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
                                decoration: InputDecoration(
                                  labelText:
                                      'Max alan (${areaFilterUnit.suffix})',
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
                                  areaFilterUnit = AreaUnit.squareMeter;
                                  blockController.clear();
                                  parcelController.clear();
                                  roomLayoutController.clear();
                                  minSquareMetersController.clear();
                                  maxSquareMetersController.clear();
                                  maxBuildingAgeController.clear();
                                  minBathroomController.clear();
                                  minBalconyController.clear();
                                  floorCountController.clear();
                                  floorNumberController.clear();
                                  frontageController.clear();
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
        _areaFilterUnit = areaFilterUnit;
        _blockController.text = blockController.text;
        _parcelController.text = parcelController.text;
        _roomLayoutController.text = roomLayoutController.text;
        _minSquareMetersController.text = minSquareMetersController.text;
        _maxSquareMetersController.text = maxSquareMetersController.text;
        _maxBuildingAgeController.text = maxBuildingAgeController.text;
        _minBathroomController.text = minBathroomController.text;
        _minBalconyController.text = minBalconyController.text;
        _floorCountController.text = floorCountController.text;
        _floorNumberController.text = floorNumberController.text;
        _frontageController.text = frontageController.text;
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
    floorCountController.dispose();
    floorNumberController.dispose();
    frontageController.dispose();
  }

  int? _parseOptionalInt(String value) {
    final raw = value.trim();
    if (raw.isEmpty) {
      return null;
    }
    return int.tryParse(raw);
  }

  double? _parseFilterArea(String value) {
    final parsed = parseOptionalNumberInput(value);
    if (parsed == null) {
      return null;
    }
    if (_type == PropertyType.land || _type == PropertyType.field) {
      return _areaFilterUnit.toSquareMeters(parsed);
    }
    return parsed;
  }
}

class _ListingsData {
  const _ListingsData({
    this.listings = const [],
    this.interestCounts = const {},
  });

  final List<PropertyListing> listings;
  final Map<int, int> interestCounts;
}

class _ListingToolbar extends StatelessWidget {
  const _ListingToolbar({
    required this.view,
    required this.searchOpen,
    required this.searchController,
    required this.activeFilterCount,
    required this.onViewChanged,
    required this.onSearchChanged,
    required this.onSearchToggle,
    required this.onFilterPressed,
  });

  final _ListingsView view;
  final bool searchOpen;
  final TextEditingController searchController;
  final int activeFilterCount;
  final ValueChanged<_ListingsView> onViewChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchToggle;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          children: [
            Row(
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
                IconButton.filledTonal(
                  tooltip: searchController.text.isNotEmpty
                      ? 'Aramayı temizle'
                      : 'Ara',
                  onPressed: onSearchToggle,
                  icon: Icon(
                    searchController.text.isNotEmpty
                        ? Icons.close
                        : Icons.search,
                  ),
                ),
                const SizedBox(width: 8),
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: searchOpen
                  ? Padding(
                      key: const ValueKey('listing-search'),
                      padding: const EdgeInsets.only(top: 10),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          labelText: 'İlanlarda ara',
                          hintText: 'Bina, site, açıklama, cephe...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: onSearchChanged,
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('listing-search-off')),
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
                final style = _styleForListing(listing);
                return Marker(
                  point: LatLng(listing.latitude!, listing.longitude!),
                  width: 52,
                  height: 52,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () => _showListingPreview(listing),
                    child: _MapMarkerBadge(style: style),
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
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: IconButton.filledTonal(
                tooltip: 'Harita açıklaması',
                onPressed: _showMapLegend,
                icon: const Icon(Icons.info_outline),
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

  void _showMapLegend() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _MapLegendSheet(),
    );
  }

  _MapMarkerStyle _styleForListing(PropertyListing listing) {
    switch (listing.type) {
      case PropertyType.apartment:
        switch (listing.housingKind) {
          case HousingKind.detached:
            return _mapMarkerDetached;
          case HousingKind.site:
            return _mapMarkerSite;
          case HousingKind.apartment:
          case null:
            return _mapMarkerApartment;
        }
      case PropertyType.land:
        return _mapMarkerLand;
      case PropertyType.field:
        return _mapMarkerField;
    }
  }
}

class _MapLegendSheet extends StatelessWidget {
  const _MapLegendSheet();

  @override
  Widget build(BuildContext context) {
    final styles = [
      _mapMarkerApartment,
      _mapMarkerSite,
      _mapMarkerDetached,
      _mapMarkerLand,
      _mapMarkerField,
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Harita açıklaması',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ...styles.map(
              (style) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(
                  width: 40,
                  height: 40,
                  child: _MapMarkerBadge(style: style, compact: true),
                ),
                title: Text(style.label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapMarkerBadge extends StatelessWidget {
  const _MapMarkerBadge({
    required this.style,
    this.compact = false,
  });

  final _MapMarkerStyle style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 46.0;
    final iconSize = compact ? 19.0 : 25.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style.color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(style.icon, color: Colors.white, size: iconSize),
    );
  }
}

class _MapMarkerStyle {
  const _MapMarkerStyle({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

const _mapMarkerApartment = _MapMarkerStyle(
  label: 'Apartman',
  icon: Icons.apartment_outlined,
  color: Color(0xFF156C5B),
);

const _mapMarkerSite = _MapMarkerStyle(
  label: 'Site',
  icon: Icons.apartment_outlined,
  color: Color(0xFF6D4BC3),
);

const _mapMarkerDetached = _MapMarkerStyle(
  label: 'Müstakil',
  icon: Icons.home_outlined,
  color: Color(0xFF2F7D32),
);

const _mapMarkerLand = _MapMarkerStyle(
  label: 'Arsa',
  icon: Icons.terrain_outlined,
  color: Color(0xFF8A5A18),
);

const _mapMarkerField = _MapMarkerStyle(
  label: 'Tarla',
  icon: Icons.agriculture_outlined,
  color: Color(0xFF407A36),
);
