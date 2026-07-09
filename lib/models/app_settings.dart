class AppSettings {
  const AppSettings({
    this.agencyName = '',
    this.agentName = '',
    this.agentPhone = '',
    this.updatedAt,
  });

  final String agencyName;
  final String agentName;
  final String agentPhone;
  final DateTime? updatedAt;

  bool get isComplete =>
      agencyName.trim().isNotEmpty &&
      agentName.trim().isNotEmpty &&
      agentPhone.trim().isNotEmpty;

  AppSettings copyWith({
    String? agencyName,
    String? agentName,
    String? agentPhone,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      agencyName: agencyName ?? this.agencyName,
      agentName: agentName ?? this.agentName,
      agentPhone: agentPhone ?? this.agentPhone,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': 1,
      'agency_name': agencyName.trim(),
      'agent_name': agentName.trim(),
      'agent_phone': agentPhone.trim(),
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory AppSettings.fromMap(Map<String, Object?> map) {
    return AppSettings(
      agencyName: map['agency_name'] as String? ?? '',
      agentName: map['agent_name'] as String? ?? '',
      agentPhone: map['agent_phone'] as String? ?? '',
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.tryParse(map['updated_at'] as String),
    );
  }
}
