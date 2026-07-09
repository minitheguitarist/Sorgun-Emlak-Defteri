import 'package:flutter/material.dart';

import '../models/property_listing.dart';
import '../services/address_repository.dart';
import '../services/app_database.dart';
import '../services/photo_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/listing_card.dart';
import 'add_edit_listing_screen.dart';

enum _EditListingStatus {
  active,
  sold,
  deleted;

  String get label {
    switch (this) {
      case _EditListingStatus.active:
        return 'Aktif';
      case _EditListingStatus.sold:
        return 'Satılan';
      case _EditListingStatus.deleted:
        return 'Silinen';
    }
  }

  IconData get icon {
    switch (this) {
      case _EditListingStatus.active:
        return Icons.sell_outlined;
      case _EditListingStatus.sold:
        return Icons.check_circle_outline;
      case _EditListingStatus.deleted:
        return Icons.delete_outline;
    }
  }
}

class EditSelectionScreen extends StatefulWidget {
  const EditSelectionScreen({
    super.key,
    required this.database,
    required this.addressRepository,
    required this.photoService,
    required this.onChanged,
    required this.refreshNonce,
  });

  final AppDatabase database;
  final AddressRepository addressRepository;
  final PhotoService photoService;
  final VoidCallback onChanged;
  final int refreshNonce;

  @override
  State<EditSelectionScreen> createState() => _EditSelectionScreenState();
}

class _EditSelectionScreenState extends State<EditSelectionScreen> {
  late Future<_EditListingsData> _future;
  final _searchController = TextEditingController();
  _EditListingStatus _status = _EditListingStatus.active;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant EditSelectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshNonce != widget.refreshNonce) {
      _refresh();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadData());
    await _future;
  }

  Future<_EditListingsData> _loadData() async {
    final listings = switch (_status) {
      _EditListingStatus.active => await widget.database.getActiveListings(),
      _EditListingStatus.sold => await widget.database.getSoldListings(),
      _EditListingStatus.deleted => await widget.database.getDeletedListings(),
    };
    final interestCounts = await widget.database.getListingInterestCounts();
    return _EditListingsData(
      listings: listings,
      interestCounts: interestCounts,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Column(
            children: [
              SegmentedButton<_EditListingStatus>(
                segments: _EditListingStatus.values
                    .map(
                      (status) => ButtonSegment<_EditListingStatus>(
                        value: status,
                        icon: Icon(status.icon),
                        label: Text(status.label),
                      ),
                    )
                    .toList(),
                selected: {_status},
                onSelectionChanged: (value) {
                  setState(() {
                    _status = value.first;
                    _future = _loadData();
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'İlan adı, mahalle, ada veya parsel ara',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<_EditListingsData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data ?? const _EditListingsData();
              final listings = _filter(data.listings);
              if (listings.isEmpty) {
                return EmptyState(
                  icon: _status.icon,
                  title: '${_status.label} ilan yok',
                  message: _emptyMessage,
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: listings.length,
                  itemBuilder: (context, index) {
                    final listing = listings[index];
                    return ListingCard(
                      listing: listing,
                      interestCount: data.interestCounts[listing.id] ?? 0,
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                      onTap: () async {
                        final changed = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (context) => AddEditListingScreen(
                              database: widget.database,
                              addressRepository: widget.addressRepository,
                              photoService: widget.photoService,
                              listing: listing,
                              standalone: true,
                              onSaved: widget.onChanged,
                            ),
                          ),
                        );
                        if (changed == true && mounted) {
                          widget.onChanged();
                          await _refresh();
                        }
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String get _emptyMessage {
    switch (_status) {
      case _EditListingStatus.active:
        return 'Aktif ilan eklemek için Ekleme ekranını kullanın.';
      case _EditListingStatus.sold:
        return 'Satılan ilanları buradan düzenleyebilir veya tekrar aktif yapabilirsiniz.';
      case _EditListingStatus.deleted:
        return 'Silinen ilanlar burada geri alınabilir.';
    }
  }

  List<PropertyListing> _filter(List<PropertyListing> listings) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return listings;
    }
    return listings.where((listing) {
      final haystack = [
        listing.displayTitle,
        listing.placeName,
        listing.streetName,
        listing.blockNo ?? '',
        listing.parcelNo ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }
}

class _EditListingsData {
  const _EditListingsData({
    this.listings = const [],
    this.interestCounts = const {},
  });

  final List<PropertyListing> listings;
  final Map<int, int> interestCounts;
}
