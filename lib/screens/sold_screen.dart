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
  late Future<List<PropertyListing>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.database.getSoldListings();
  }

  @override
  void didUpdateWidget(covariant SoldScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshNonce != widget.refreshNonce) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = widget.database.getSoldListings());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PropertyListing>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final listings = snapshot.data ?? const [];
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
