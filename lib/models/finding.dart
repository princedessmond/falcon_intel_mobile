class Alert {
  final String id;
  final String title;
  final String? description;
  final String severity;
  final String? source;
  final String? sourceType;
  final String? category;
  final String? timestamp;
  final String? createdAt;
  final String? status;
  final String? county;
  final List<dynamic>? indicators;

  Alert({
    required this.id,
    required this.title,
    this.description,
    required this.severity,
    this.source,
    this.sourceType,
    this.category,
    this.timestamp,
    this.createdAt,
    this.status,
    this.county,
    this.indicators,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title'] ?? 'Untitled',
      description: json['description'] ?? json['detail'],
      severity: json['severity'] ?? 'medium',
      source: json['source']?.toString(),
      sourceType: json['source_type']?.toString(),
      category: json['category']?.toString(),
      timestamp: json['timestamp'] ?? json['created_at'] ?? json['discovered_at'],
      createdAt: json['created_at'],
      status: json['status']?.toString(),
      county: json['county']?.toString(),
      indicators: json['indicators'] is List ? json['indicators'] as List : null,
    );
  }
}

class Watch {
  final String id;
  final String query;
  final List<String>? sources;
  final bool isActive;
  final bool liveFetch;
  final int? pollInterval;
  final String? lastTriggered;
  final String? createdAt;

  Watch({
    required this.id,
    required this.query,
    this.sources,
    required this.isActive,
    required this.liveFetch,
    this.pollInterval,
    this.lastTriggered,
    this.createdAt,
  });

  factory Watch.fromJson(Map<String, dynamic> json) {
    return Watch(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      query: json['query'] ?? '',
      sources: json['sources'] is List ? List<String>.from(json['sources']) : null,
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      liveFetch: json['live_fetch'] ?? json['liveFetch'] ?? false,
      pollInterval: json['poll_interval_minutes'] ?? json['pollInterval'],
      lastTriggered: json['last_triggered'] ?? json['lastTriggered'],
      createdAt: json['created_at'] ?? json['createdAt'],
    );
  }
}
