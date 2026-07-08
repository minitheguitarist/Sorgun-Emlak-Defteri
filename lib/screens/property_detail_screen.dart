import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/price_history.dart';
import '../models/property_listing.dart';
import '../models/property_type.dart';
import '../services/app_database.dart';
import '../services/formatters.dart';
import '../services/location_links.dart';
import '../widgets/listing_card.dart';

class PropertyDetailScreen extends StatefulWidget {
  const PropertyDetailScreen({
    super.key,
    required this.database,
    required this.listing,
    this.soldView = false,
  });

  final AppDatabase database;
  final PropertyListing listing;
  final bool soldView;

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  late PropertyListing _listing;
  late Future<List<PriceHistory>> _historyFuture;
  bool _privateVisible = false;

  @override
  void initState() {
    super.initState();
    _listing = widget.listing;
    _historyFuture = _loadHistory();
  }

  Future<List<PriceHistory>> _loadHistory() {
    final id = _listing.id;
    if (id == null) {
      return Future.value(const []);
    }
    return widget.database.getPriceHistory(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            stretch: true,
            title: Text(_listing.type.label),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'listing-photo-${_listing.id ?? _listing.createdAt}',
                child: _PhotoPager(paths: _listing.photoPaths),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _listing.displayTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (_listing.isSold)
                        Chip(
                          avatar: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Satıldı'),
                          side: BorderSide.none,
                          backgroundColor: theme.colorScheme.tertiaryContainer,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _listing.addressLine,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _PublicInfoGrid(listing: _listing, soldView: widget.soldView),
                  if ((_listing.ownerName ?? '').trim().isNotEmpty ||
                      _listing.ownerPhoneList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _OwnerInfo(listing: _listing, onCall: _callOwner),
                  ],
                  if (_listing.hasLocation) ...[
                    const SizedBox(height: 12),
                    _LocationActions(
                      listing: _listing,
                      onOpen: _openLocation,
                      onShare: _shareLocation,
                      onNearby: _showNearbyOptions,
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (_listing.type != PropertyType.apartment)
                    _ParcelInfo(listing: _listing),
                  if (_listing.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Açıklama',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _listing.description,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      setState(() => _privateVisible = !_privateVisible);
                    },
                    icon: Icon(
                      _privateVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    label: Text(
                      _privateVisible
                          ? 'Gizli bilgileri kapat'
                          : 'Gizli bilgileri göster',
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _privateVisible
                        ? _PrivatePanel(
                            key: const ValueKey('private-panel'),
                            listing: _listing,
                            historyFuture: _historyFuture,
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('private-panel-hidden'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLocation() async {
    final opened = await openListingLocation(_listing);
    if (!mounted || opened) {
      return;
    }
    _showSnack('Konum açılamadı.');
  }

  Future<void> _shareLocation() async {
    try {
      await shareListingLocation(_listing);
    } catch (_) {
      if (mounted) {
        _showSnack('Konum paylaşılamadı.');
      }
    }
  }

  Future<void> _callOwner(String phoneNumber) async {
    final phone = phoneNumber.trim();
    if (phone.isEmpty) {
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) {
        return;
      }
    } catch (_) {
      // Fall back to copy below.
    }

    await Clipboard.setData(ClipboardData(text: phone));
    if (mounted) {
      _showSnack('Telefon numarası kopyalandı.');
    }
  }

  Future<void> _showNearbyOptions() async {
    final radius = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.near_me_outlined),
              title: const Text('500 metre içindeki ilanlar'),
              onTap: () => Navigator.of(context).pop(500),
            ),
            ListTile(
              leading: const Icon(Icons.explore_outlined),
              title: const Text('1 km içindeki ilanlar'),
              onTap: () => Navigator.of(context).pop(1000),
            ),
          ],
        ),
      ),
    );
    if (radius == null) {
      return;
    }
    await _showNearbyListings(radius);
  }

  Future<void> _showNearbyListings(double radiusMeters) async {
    final latitude = _listing.latitude;
    final longitude = _listing.longitude;
    if (latitude == null || longitude == null) {
      return;
    }

    final listings = await widget.database.getActiveListings();
    final nearby = listings
        .where((item) => item.id != _listing.id && item.hasLocation)
        .map(
          (item) => MapEntry(
            item,
            _distanceMeters(
              latitude,
              longitude,
              item.latitude!,
              item.longitude!,
            ),
          ),
        )
        .where((entry) => entry.value <= radiusMeters)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: nearby.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${radiusMeters >= 1000 ? '1 km' : '500 m'} içinde başka aktif ilan yok.',
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: nearby.length,
                itemBuilder: (context, index) {
                  final item = nearby[index].key;
                  final distance = nearby[index].value;
                  return ListingCard(
                    listing: item,
                    trailing: Text('${distance.round()} m'),
                    onTap: () {
                      final navigator = Navigator.of(this.context);
                      Navigator.of(context).pop();
                      navigator.pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (context) => PropertyDetailScreen(
                            database: widget.database,
                            listing: item,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  double _distanceMeters(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const earthRadiusMeters = 6371000.0;
    final startLat = startLatitude * math.pi / 180;
    final endLat = endLatitude * math.pi / 180;
    final deltaLat = (endLatitude - startLatitude) * math.pi / 180;
    final deltaLon = (endLongitude - startLongitude) * math.pi / 180;
    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(startLat) *
            math.cos(endLat) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _PhotoPager extends StatelessWidget {
  const _PhotoPager({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (paths.isEmpty) {
      return ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.home_work_outlined,
          size: 86,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return PageView.builder(
      itemCount: paths.length,
      itemBuilder: (context, index) {
        final file = File(paths[index]);
        if (!file.existsSync()) {
          return GestureDetector(
            onTap: () => _openFullScreen(context, index),
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.broken_image_outlined,
                size: 70,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return GestureDetector(
          onTap: () => _openFullScreen(context, index),
          child: Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 70,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _openFullScreen(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _FullScreenPhotoViewer(
          paths: paths,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _FullScreenPhotoViewer extends StatefulWidget {
  const _FullScreenPhotoViewer({
    required this.paths,
    required this.initialIndex,
  });

  final List<String> paths;
  final int initialIndex;

  @override
  State<_FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<_FullScreenPhotoViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1}/${widget.paths.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.paths.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (context, index) {
          final file = File(widget.paths[index]);
          if (!file.existsSync()) {
            return const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white70,
                size: 70,
              ),
            );
          }
          return Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Image.file(
                file,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 70,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PublicInfoGrid extends StatelessWidget {
  const _PublicInfoGrid({required this.listing, required this.soldView});

  final PropertyListing listing;
  final bool soldView;

  @override
  Widget build(BuildContext context) {
    final price = soldView ? listing.finalPrice : listing.salePrice;
    final priceLabel = listing.dealType?.priceLabel ?? 'Satış fiyatı';
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = constraints.maxWidth > 560
            ? (constraints.maxWidth - 20) / 3
            : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: tileWidth,
              child: _InfoTile(label: priceLabel, value: formatMoney(price)),
            ),
            if (listing.dealType != null)
              SizedBox(
                width: tileWidth,
                child: _InfoTile(
                  label: 'İlan durumu',
                  value: listing.dealType!.label,
                ),
              ),
            SizedBox(
              width: tileWidth,
              child: _InfoTile(label: 'Tip', value: listing.type.label),
            ),
            SizedBox(
              width: tileWidth,
              child: _InfoTile(label: 'Konum', value: listing.placeName),
            ),
            if (listing.streetName.isNotEmpty)
              SizedBox(
                width: tileWidth,
                child:
                    _InfoTile(label: 'Cadde/Sokak', value: listing.streetName),
              ),
            if (listing.roomLayout?.trim().isNotEmpty == true)
              SizedBox(
                width: tileWidth,
                child: _InfoTile(label: 'Oda tipi', value: listing.roomLayout!),
              ),
            if (listing.squareMeters != null && listing.squareMeters! > 0)
              SizedBox(
                width: tileWidth,
                child: _InfoTile(
                  label: 'Metrekare',
                  value: formatArea(listing.squareMeters!),
                ),
              ),
            if (listing.buildingAge != null)
              SizedBox(
                width: tileWidth,
                child: _InfoTile(
                  label: 'Bina yaşı',
                  value: listing.buildingAge.toString(),
                ),
              ),
            if (listing.bathroomCount != null)
              SizedBox(
                width: tileWidth,
                child: _InfoTile(
                  label: 'Banyo',
                  value: listing.bathroomCount.toString(),
                ),
              ),
            if (listing.balconyCount != null)
              SizedBox(
                width: tileWidth,
                child: _InfoTile(
                  label: 'Balkon',
                  value: listing.balconyCount.toString(),
                ),
              ),
            if (listing.housingKind != null)
              SizedBox(
                width: tileWidth,
                child: _InfoTile(
                  label: 'Konut tipi',
                  value: listing.housingKind!.label,
                ),
              ),
            if (listing.floorCount != null)
              SizedBox(
                width: tileWidth,
                child: _InfoTile(
                  label: 'Toplam kat',
                  value: listing.floorCount.toString(),
                ),
              ),
            if (listing.floorNumber != null)
              SizedBox(
                width: tileWidth,
                child: _InfoTile(
                  label: 'Bulunduğu kat',
                  value: listing.floorNumber.toString(),
                ),
              ),
            if (listing.frontage?.trim().isNotEmpty == true)
              SizedBox(
                width: tileWidth,
                child: _InfoTile(
                  label: 'Cephe',
                  value: listing.frontage!.trim(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OwnerInfo extends StatelessWidget {
  const _OwnerInfo({
    required this.listing,
    required this.onCall,
  });

  final PropertyListing listing;
  final ValueChanged<String> onCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ownerName = listing.ownerName?.trim();
    final ownerPhones = listing.ownerPhoneList;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.person_outline, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ownerName == null || ownerName.isEmpty
                      ? 'Mülk sahibi'
                      : ownerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (ownerPhones.isNotEmpty)
                  ...ownerPhones.map(
                    (phone) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (ownerPhones.isNotEmpty)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: ownerPhones
                  .map(
                    (phone) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: IconButton.filledTonal(
                        tooltip: '$phone ara',
                        onPressed: () => onCall(phone),
                        icon: const Icon(Icons.call_outlined),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _ParcelInfo extends StatelessWidget {
  const _ParcelInfo({required this.listing});

  final PropertyListing listing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _InfoTile(label: 'Ada', value: listing.blockNo ?? '-'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _InfoTile(label: 'Parsel', value: listing.parcelNo ?? '-'),
        ),
      ],
    );
  }
}

class _LocationActions extends StatelessWidget {
  const _LocationActions({
    required this.listing,
    required this.onOpen,
    required this.onShare,
    required this.onNearby,
  });

  final PropertyListing listing;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onNearby;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  formatCoordinates(
                    latitude: listing.latitude!,
                    longitude: listing.longitude!,
                  ),
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
                  onPressed: onOpen,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Konumu aç'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_outlined),
                  label: const Text('Konum paylaş'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onNearby,
              icon: const Icon(Icons.near_me_outlined),
              label: const Text('Yakındaki ilanlar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivatePanel extends StatelessWidget {
  const _PrivatePanel({
    super.key,
    required this.listing,
    required this.historyFuture,
  });

  final PropertyListing listing;
  final Future<List<PriceHistory>> historyFuture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gizli bilgiler',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoTile(
                compact: true,
                label: 'Maliyet',
                value: formatMoney(listing.costPrice),
              ),
              _InfoTile(
                compact: true,
                label: 'Güncel kar',
                value: formatMoney(listing.activeProfit),
              ),
              _InfoTile(
                compact: true,
                label: 'Güncel kar marjı',
                value: formatPercent(listing.activeProfitPercent),
              ),
              if (listing.isSold) ...[
                _InfoTile(
                  compact: true,
                  label: 'Satış',
                  value: formatMoney(listing.finalPrice),
                ),
                _InfoTile(
                  compact: true,
                  label: 'Nihai kar',
                  value: formatMoney(listing.finalProfit),
                ),
                _InfoTile(
                  compact: true,
                  label: 'Nihai kar marjı',
                  value: formatPercent(listing.finalProfitPercent),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Fiyat geçmişi',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<PriceHistory>>(
            future: historyFuture,
            builder: (context, snapshot) {
              final history = snapshot.data ?? const [];
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (history.isEmpty) {
                return Text(
                  'Henüz fiyat değişikliği yok.',
                  style: theme.textTheme.bodyMedium,
                );
              }
              return Column(
                children: history.map((item) {
                  final direction = item.newPrice >= item.oldPrice
                      ? Icons.trending_up
                      : Icons.trending_down;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(direction),
                    title: Text(
                      '${formatMoney(item.oldPrice)} -> ${formatMoney(item.newPrice)}',
                    ),
                    subtitle: Text(formatDate(item.changedAt)),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
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
      width: compact ? 154 : null,
      constraints: BoxConstraints(minHeight: compact ? 0 : 92),
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
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
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
