class PriceHistory {
  const PriceHistory({
    this.id,
    required this.listingId,
    required this.oldPrice,
    required this.newPrice,
    required this.changedAt,
  });

  final int? id;
  final int listingId;
  final double oldPrice;
  final double newPrice;
  final DateTime changedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'listing_id': listingId,
      'old_price': oldPrice,
      'new_price': newPrice,
      'changed_at': changedAt.toIso8601String(),
    };
  }

  factory PriceHistory.fromMap(Map<String, Object?> map) {
    return PriceHistory(
      id: map['id'] as int?,
      listingId: map['listing_id'] as int,
      oldPrice: (map['old_price'] as num).toDouble(),
      newPrice: (map['new_price'] as num).toDouble(),
      changedAt: DateTime.parse(map['changed_at'] as String),
    );
  }
}
