import 'package:flutter/material.dart';

import '../models/property_listing.dart';
import '../services/app_database.dart';
import '../widgets/empty_state.dart';
import '../widgets/listing_card.dart';
import 'property_detail_screen.dart';

class SoldScreen extends StatefulWidget {
  const SoldScreen({
    super.key,
    required this.database,
    required this.refreshNonce,
  });

  final AppDatabase database;
  final int refreshNonce;

  @override
  State<SoldScreen> createState() => _SoldScreenState();
}

class _SoldScreenState extends State<SoldScreen> {
  late Future<_SoldListingsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  @override
  void didUpdateWidget(covariant SoldScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshNonce != widget.refreshNonce) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadData());
    await _future;
  }

  Future<_SoldListingsData> _loadData() async {
    final listings = await widget.database.getSoldListings();
    final interestCounts = await widget.database.getListingInterestCounts();
    return _SoldListingsData(
      listings: listings,
      interestCounts: interestCounts,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SoldListingsData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data ?? const _SoldListingsData();
        final listings = data.listings;
        if (listings.isEmpty) {
          return const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Satılan kayıt yok',
            message:
                'Düzenleme ekranından satıldı işaretlenen ilanlar burada satış fiyatıyla görünür.',
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
                showSoldPrice: true,
                interestCount: data.interestCounts[listing.id] ?? 0,
                trailing: const Icon(Icons.check_circle_outline, size: 20),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => PropertyDetailScreen(
                        database: widget.database,
                        listing: listing,
                        soldView: true,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _SoldListingsData {
  const _SoldListingsData({
    this.listings = const [],
    this.interestCounts = const {},
  });

  final List<PropertyListing> listings;
  final Map<int, int> interestCounts;
}
