import 'package:flutter/material.dart';

import '../models/property_listing.dart';
import '../models/property_type.dart';
import '../services/app_database.dart';
import '../services/formatters.dart';
import '../widgets/empty_state.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({
    super.key,
    required this.database,
    required this.refreshNonce,
  });

  final AppDatabase database;
  final int refreshNonce;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  late Future<_AnalysisData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant AnalysisScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshNonce != widget.refreshNonce) {
      setState(() => _future = _load());
    }
  }

  Future<_AnalysisData> _load() async {
    final active = await widget.database.getActiveListings();
    final sold = await widget.database.getSoldListings();
    return _AnalysisData.from(active: active, sold: sold);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AnalysisData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data;
        if (data == null || data.groups.isEmpty && data.soldCount == 0) {
          return const EmptyState(
            icon: Icons.analytics_outlined,
            title: 'Analiz için veri yok',
            message: 'İlan ekledikçe mahalle/köy bazlı özetler burada görünür.',
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
          children: [
            _SummaryGrid(data: data),
            const SizedBox(height: 18),
            Text(
              'Bölge özeti',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            for (final group in data.groups) _RegionTile(group: group),
          ],
        );
      },
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.data});

  final _AnalysisData data;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MetricCard(label: 'Aktif ilan', value: data.activeCount.toString()),
        _MetricCard(
            label: 'Aktif toplam', value: formatMoney(data.activeTotal)),
        _MetricCard(label: 'Satılan', value: data.soldCount.toString()),
        _MetricCard(label: 'Satış toplamı', value: formatMoney(data.soldTotal)),
        _MetricCard(label: 'Toplam kar', value: formatMoney(data.soldProfit)),
        _MetricCard(label: 'Kar marjı', value: formatPercent(data.soldMargin)),
      ],
    );
  }
}

class _RegionTile extends StatelessWidget {
  const _RegionTile({required this.group});

  final _RegionAnalysis group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final squareMeterPrice = group.apartmentSquareMeters <= 0
        ? null
        : group.apartmentTotal / group.apartmentSquareMeters;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.placeName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricCard(
                    compact: true, label: 'İlan', value: '${group.count}'),
                _MetricCard(
                  compact: true,
                  label: 'Toplam',
                  value: formatMoney(group.total),
                ),
                _MetricCard(
                  compact: true,
                  label: 'Ortalama',
                  value: formatMoney(group.total / group.count),
                ),
                if (squareMeterPrice != null)
                  _MetricCard(
                    compact: true,
                    label: 'Ort. m²',
                    value: formatMoney(squareMeterPrice),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: compact ? 142 : 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisData {
  const _AnalysisData({
    required this.activeCount,
    required this.activeTotal,
    required this.soldCount,
    required this.soldTotal,
    required this.soldProfit,
    required this.soldMargin,
    required this.groups,
  });

  final int activeCount;
  final double activeTotal;
  final int soldCount;
  final double soldTotal;
  final double soldProfit;
  final double soldMargin;
  final List<_RegionAnalysis> groups;

  factory _AnalysisData.from({
    required List<PropertyListing> active,
    required List<PropertyListing> sold,
  }) {
    final grouped = <String, _RegionAnalysis>{};
    for (final listing in active) {
      final key = listing.placeName;
      final group = grouped.putIfAbsent(
        key,
        () => _RegionAnalysis(placeName: key),
      );
      group.add(listing);
    }
    final groups = grouped.values.toList()
      ..sort((a, b) {
        final count = b.count.compareTo(a.count);
        return count == 0 ? a.placeName.compareTo(b.placeName) : count;
      });

    final soldTotal =
        sold.fold<double>(0, (sum, item) => sum + item.finalPrice);
    final soldProfit =
        sold.fold<double>(0, (sum, item) => sum + item.finalProfit);
    return _AnalysisData(
      activeCount: active.length,
      activeTotal: active.fold<double>(0, (sum, item) => sum + item.salePrice),
      soldCount: sold.length,
      soldTotal: soldTotal,
      soldProfit: soldProfit,
      soldMargin: soldTotal <= 0 ? 0 : soldProfit / soldTotal * 100,
      groups: groups,
    );
  }
}

class _RegionAnalysis {
  _RegionAnalysis({required this.placeName});

  final String placeName;
  int count = 0;
  double total = 0;
  double apartmentTotal = 0;
  double apartmentSquareMeters = 0;

  void add(PropertyListing listing) {
    count++;
    total += listing.salePrice;
    if (listing.type == PropertyType.apartment &&
        listing.squareMeters != null &&
        listing.squareMeters! > 0) {
      apartmentTotal += listing.salePrice;
      apartmentSquareMeters += listing.squareMeters!;
    }
  }
}
