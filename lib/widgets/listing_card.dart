import 'dart:io';

import 'package:flutter/material.dart';

import '../models/property_listing.dart';
import '../models/property_type.dart';
import '../services/formatters.dart';

class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.trailing,
    this.showSoldPrice = false,
  });

  final PropertyListing listing;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showSoldPrice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _typeColor(context, listing.type);
    final price = showSoldPrice ? listing.finalPrice : listing.salePrice;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 156,
          child: Row(
            children: [
              Hero(
                tag: 'listing-photo-${listing.id ?? listing.createdAt}',
                child: _ListingImage(
                  path: listing.photoPaths.isEmpty
                      ? null
                      : listing.photoPaths.first,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              listing.type.label,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (trailing != null) trailing!,
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        listing.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        listing.addressLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatMoney(price),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (listing.type != PropertyType.apartment)
                            Text(
                              listing.parcelLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall,
                            )
                          else if (listing.apartmentSpecsLine.isNotEmpty)
                            Text(
                              listing.apartmentSpecsLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(BuildContext context, PropertyType type) {
    switch (type) {
      case PropertyType.apartment:
        return Theme.of(context).colorScheme.primary;
      case PropertyType.land:
        return const Color(0xFF8A5A18);
      case PropertyType.field:
        return const Color(0xFF407A36);
    }
  }
}

class _ListingImage extends StatelessWidget {
  const _ListingImage({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 128,
      height: double.infinity,
      child: path == null || !File(path!).existsSync()
          ? ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.real_estate_agent_outlined,
                size: 42,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Image.file(
              File(path!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 40,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
    );
  }
}
