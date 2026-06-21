import 'package:flutter/material.dart';

import '../models/property_listing.dart';
import '../services/address_repository.dart';
import '../services/app_database.dart';
import '../services/photo_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/listing_card.dart';
import 'add_edit_listing_screen.dart';

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
  late Future<List<PropertyListing>> _future;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = widget.database.getActiveListings();
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
    setState(() => _future = widget.database.getActiveListings());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'İlan adı, mahalle, ada veya parsel ara',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<PropertyListing>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final listings = _filter(snapshot.data ?? const []);
              if (listings.isEmpty) {
                return const EmptyState(
                  icon: Icons.edit_note_outlined,
                  title: 'Düzenlenecek aktif ilan yok',
                  message:
                      'Satılmış kayıtlar Satılanlar ekranında tutulur; aktif ilan eklemek için Ekleme ekranını kullanın.',
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
