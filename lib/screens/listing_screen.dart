import 'package:flutter/material.dart';

import '../models/property_listing.dart';
import '../models/property_type.dart';
import '../services/address_repository.dart';
import '../services/app_database.dart';
import '../services/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/listing_card.dart';
import 'property_detail_screen.dart';

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
  PropertyType? _type;
  PlaceKind? _placeKind;
  String? _placeName;
  String? _streetName;
  final _blockController = TextEditingController();
  final _parcelController = TextEditingController();
  final _roomLayoutController = TextEditingController();
  final _minSquareMetersController = TextEditingController();
  final _maxSquareMetersController = TextEditingController();

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
            _FilterPanel(
              addressBook: addressBook,
              type: _type,
              placeKind: _placeKind,
              placeName: _placeName,
              streetName: _streetName,
              blockController: _blockController,
              parcelController: _parcelController,
              roomLayoutController: _roomLayoutController,
              minSquareMetersController: _minSquareMetersController,
              maxSquareMetersController: _maxSquareMetersController,
              onTypeChanged: (value) => setState(() => _type = value),
              onPlaceKindChanged: (value) {
                setState(() {
                  _placeKind = value;
                  _placeName = null;
                  _streetName = null;
                });
              },
              onPlaceNameChanged: (value) {
                setState(() => _placeName = value);
              },
              onStreetChanged: (value) {
                setState(() => _streetName = value);
              },
              onTextFilterChanged: () => setState(() {}),
              onClear: () {
                setState(() {
                  _type = null;
                  _placeKind = null;
                  _placeName = null;
                  _streetName = null;
                  _blockController.clear();
                  _parcelController.clear();
                  _roomLayoutController.clear();
                  _minSquareMetersController.clear();
                  _maxSquareMetersController.clear();
                });
              },
            ),
            Expanded(
              child: FutureBuilder<List<PropertyListing>>(
                future: _listingsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final listings = _applyFilters(snapshot.data ?? const []);
                  if (listings.isEmpty) {
                    return const EmptyState(
                      icon: Icons.real_estate_agent_outlined,
                      title: 'Aktif ilan yok',
                      message:
                          'Ekleme ekranından daire, arsa veya tarla kaydı oluşturabilirsiniz.',
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
                            onTap: () {
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

  List<PropertyListing> _applyFilters(List<PropertyListing> listings) {
    final block = _blockController.text.trim().toLowerCase();
    final parcel = _parcelController.text.trim().toLowerCase();
    final roomLayout = _roomLayoutController.text.trim().toLowerCase();
    final minSquareMeters =
        parseOptionalNumberInput(_minSquareMetersController.text);
    final maxSquareMeters =
        parseOptionalNumberInput(_maxSquareMetersController.text);

    return listings.where((listing) {
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
      return true;
    }).toList();
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.addressBook,
    required this.type,
    required this.placeKind,
    required this.placeName,
    required this.streetName,
    required this.blockController,
    required this.parcelController,
    required this.roomLayoutController,
    required this.minSquareMetersController,
    required this.maxSquareMetersController,
    required this.onTypeChanged,
    required this.onPlaceKindChanged,
    required this.onPlaceNameChanged,
    required this.onStreetChanged,
    required this.onTextFilterChanged,
    required this.onClear,
  });

  final AddressBook? addressBook;
  final PropertyType? type;
  final PlaceKind? placeKind;
  final String? placeName;
  final String? streetName;
  final TextEditingController blockController;
  final TextEditingController parcelController;
  final TextEditingController roomLayoutController;
  final TextEditingController minSquareMetersController;
  final TextEditingController maxSquareMetersController;
  final ValueChanged<PropertyType?> onTypeChanged;
  final ValueChanged<PlaceKind?> onPlaceKindChanged;
  final ValueChanged<String?> onPlaceNameChanged;
  final ValueChanged<String?> onStreetChanged;
  final VoidCallback onTextFilterChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final places = addressBook == null
        ? const <String>[]
        : placeKind == null
            ? [
                ...addressBook!.neighborhoods,
                ...addressBook!.villages,
              ]
            : addressBook!.placesFor(placeKind!);

    return Material(
      elevation: 1,
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            _FilterDropdown<PropertyType?>(
              width: 150,
              value: type,
              label: 'Tip',
              items: [
                const DropdownMenuItem<PropertyType?>(
                  value: null,
                  child: Text('Hepsi'),
                ),
                ...PropertyType.values.map<DropdownMenuItem<PropertyType?>>(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item.label),
                  ),
                ),
              ],
              onChanged: onTypeChanged,
            ),
            _FilterDropdown<PlaceKind?>(
              width: 150,
              value: placeKind,
              label: 'Yer türü',
              items: [
                const DropdownMenuItem<PlaceKind?>(
                  value: null,
                  child: Text('Hepsi'),
                ),
                ...PlaceKind.values.map<DropdownMenuItem<PlaceKind?>>(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item.label),
                  ),
                ),
              ],
              onChanged: onPlaceKindChanged,
            ),
            _FilterDropdown<String?>(
              width: 230,
              value: places.contains(placeName) ? placeName : null,
              label: 'Mahalle/Köy',
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Hepsi'),
                ),
                ...places.map<DropdownMenuItem<String?>>(
                  (item) => DropdownMenuItem(value: item, child: Text(item)),
                ),
              ],
              onChanged: onPlaceNameChanged,
            ),
            _FilterDropdown<String?>(
              width: 220,
              value: (addressBook?.streets ?? const []).contains(streetName)
                  ? streetName
                  : null,
              label: 'Cadde/Sokak',
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Hepsi'),
                ),
                ...(addressBook?.streets ?? const <String>[])
                    .map<DropdownMenuItem<String?>>(
                  (item) => DropdownMenuItem(value: item, child: Text(item)),
                ),
              ],
              onChanged: onStreetChanged,
            ),
            SizedBox(
              width: 118,
              child: TextField(
                controller: roomLayoutController,
                onChanged: (_) => onTextFilterChanged(),
                decoration: const InputDecoration(
                  labelText: 'Oda',
                  hintText: '2+1',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 120,
              child: TextField(
                controller: minSquareMetersController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => onTextFilterChanged(),
                decoration: const InputDecoration(
                  labelText: 'Min m²',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 120,
              child: TextField(
                controller: maxSquareMetersController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => onTextFilterChanged(),
                decoration: const InputDecoration(
                  labelText: 'Max m²',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: TextField(
                controller: blockController,
                onChanged: (_) => onTextFilterChanged(),
                decoration: const InputDecoration(
                  labelText: 'Ada',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              child: TextField(
                controller: parcelController,
                onChanged: (_) => onTextFilterChanged(),
                decoration: const InputDecoration(
                  labelText: 'Parsel',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Filtreleri temizle',
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.width,
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  final double width;
  final T value;
  final String label;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        width: width,
        child: DropdownButtonFormField<T>(
          key: ValueKey('filter-$label-$value-${items.length}'),
          initialValue: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
          ),
        ),
      ),
    );
  }
}
