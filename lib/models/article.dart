class Article {
  final String id;
  final String title;
  final String? description;
  final String? content;
  final String? url;
  final String? imageUrl;
  final String? source;
  final String? category;
  final List<String> categories;
  final String? publishedAt;
  final double? kenyaRelevance;
  final String? threatLevel;
  final String? region;
  final List<String> countiesDetected;
  final List<String>? tags;

  Article({
    required this.id,
    required this.title,
    this.description,
    this.content,
    this.url,
    this.imageUrl,
    this.source,
    this.category,
    this.categories = const [],
    this.publishedAt,
    this.kenyaRelevance,
    this.threatLevel,
    this.region,
    this.countiesDetected = const [],
    this.tags,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    // Strip HTML tags from text fields
    String stripHtml(String? text) {
      if (text == null) return '';
      // Remove HTML tags
      var clean = text.replaceAll(RegExp(r'<[^>]*>'), '');
      // Decode common HTML entities
      clean = clean
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#039;', "'")
          .replaceAll('&apos;', "'")
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&ldquo;', '"')
          .replaceAll('&rdquo;', '"');
      // Collapse whitespace
      clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
      return clean;
    }

    // Try to get a timestamp from multiple fields
    String? getTimestamp() {
      // Try all possible timestamp fields (most specific first)
      for (final field in [
        'published_at', 'publishedAt', 'timestamp',
        'analyzed_at', 'analyzedAt',
        'created_at', 'createdAt',
        'discovered_at', 'discoveredAt',
      ]) {
        final val = json[field];
        if (val != null && val.toString().isNotEmpty) {
          return val.toString();
        }
      }
      // Fall back to MongoDB ObjectId timestamp (first 4 bytes = Unix epoch)
      final id = json['_id'];
      if (id != null) {
        final idStr = id.toString();
        if (idStr.length >= 8) {
          try {
            final hex = idStr.substring(0, 8);
            final epoch = int.parse(hex, radix: 16);
            return DateTime.fromMillisecondsSinceEpoch(epoch * 1000).toIso8601String();
          } catch (_) {}
        }
      }
      return null;
    }

    return Article(
      id: json['_id']?.toString() ?? json['id'] ?? '',
      title: stripHtml(json['title']),
      description: stripHtml(json['description'] ?? json['summary']),
      content: stripHtml(json['content'] ?? json['summary']),
      url: json['url'] ?? json['link'],
      imageUrl: json['image_url'] ?? json['imageUrl'],
      source: json['source'] ?? json['source_name'],
      category: json['category'],
      categories: json['categories'] != null
          ? List<String>.from(json['categories'])
          : [],
      publishedAt: getTimestamp(),
      kenyaRelevance: (json['kenya_relevance'] ?? json['kenyaRelevance'])?.toDouble(),
      threatLevel: json['threat_level'] ?? json['threatLevel'],
      region: json['region'],
      countiesDetected: json['counties_detected'] != null
          ? List<String>.from(json['counties_detected'])
          : [],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
    );
  }
}

/// AI Analysis result from POST /api/ai/analyze
class AnalysisResult {
  final String? threatLevel;
  final double? threatScore;
  final String? aiSummary;
  final String? predictedImpact;
  final String? actionableIntelligence;
  final List<String>? recommendedCountermeasures;
  final List<String>? categories;
  final List<String>? countiesDetected;
  final List<String>? keyEntities;
  final double? confidenceScore;
  final String? aiModel;

  AnalysisResult({
    this.threatLevel,
    this.threatScore,
    this.aiSummary,
    this.predictedImpact,
    this.actionableIntelligence,
    this.recommendedCountermeasures,
    this.categories,
    this.countiesDetected,
    this.keyEntities,
    this.confidenceScore,
    this.aiModel,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    // key_entities can be a list of strings OR a list of maps like
    // [{'type': 'ORG', 'name': 'KDF'}, ...]
    List<String>? parseKeyEntities(dynamic raw) {
      if (raw == null) return null;
      if (raw is! List) return null;
      return raw.map((e) {
        if (e is String) return e;
        if (e is Map) return e['name']?.toString() ?? e.toString();
        return e.toString();
      }).toList();
    }

    return AnalysisResult(
      threatLevel: json['threat_level']?.toString(),
      threatScore: json['threat_score'] is int
          ? (json['threat_score'] as int).toDouble()
          : json['threat_score']?.toDouble(),
      aiSummary: json['ai_summary']?.toString(),
      predictedImpact: json['predicted_impact']?.toString(),
      actionableIntelligence: json['actionable_intelligence']?.toString(),
      recommendedCountermeasures: json['recommended_countermeasures'] != null
          ? (json['recommended_countermeasures'] as List).map((e) => e.toString()).toList()
          : null,
      categories: json['categories'] != null
          ? (json['categories'] as List).map((e) => e.toString()).toList()
          : null,
      countiesDetected: json['counties_detected'] != null
          ? (json['counties_detected'] as List).map((e) => e.toString()).toList()
          : null,
      keyEntities: parseKeyEntities(json['key_entities']),
      confidenceScore: json['confidence_score'] is int
          ? (json['confidence_score'] as int).toDouble()
          : json['confidence_score']?.toDouble(),
      aiModel: json['ai_model']?.toString(),
    );
  }
}
