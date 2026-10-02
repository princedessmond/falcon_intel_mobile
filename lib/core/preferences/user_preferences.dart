import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

/// User preferences — synced with the Falcon Intel backend API.
/// Both web and mobile use the same /api/preferences/ endpoint.
class UserPreferences {
  final List<String> preferredCategories;
  final List<String> preferredSeverity;
  final List<String> preferredRegions;
  final List<String> preferredCounties;
  final List<String> preferredPlatforms;

  UserPreferences({
    this.preferredCategories = const [],
    this.preferredSeverity = const [],
    this.preferredRegions = const [],
    this.preferredCounties = const [],
    this.preferredPlatforms = const [],
  });

  UserPreferences copyWith({
    List<String>? preferredCategories,
    List<String>? preferredSeverity,
    List<String>? preferredRegions,
    List<String>? preferredCounties,
    List<String>? preferredPlatforms,
  }) {
    return UserPreferences(
      preferredCategories: preferredCategories ?? this.preferredCategories,
      preferredSeverity: preferredSeverity ?? this.preferredSeverity,
      preferredRegions: preferredRegions ?? this.preferredRegions,
      preferredCounties: preferredCounties ?? this.preferredCounties,
      preferredPlatforms: preferredPlatforms ?? this.preferredPlatforms,
    );
  }

  bool get hasFilters =>
      preferredCategories.isNotEmpty ||
      preferredSeverity.isNotEmpty ||
      preferredRegions.isNotEmpty ||
      preferredCounties.isNotEmpty ||
      preferredPlatforms.isNotEmpty;

  List<T> filterArticles<T>(List<T> articles, Map<String, dynamic> Function(T) getFields) {
    if (!hasFilters) return articles;

    return articles.where((article) {
      final fields = getFields(article);
      final categories = (fields['categories'] as List?)?.cast<String>() ?? [];
      final severity = fields['severity']?.toString() ?? '';
      final region = fields['region']?.toString() ?? '';
      final counties = (fields['counties'] as List?)?.cast<String>() ?? [];
      final platform = fields['platform']?.toString() ?? '';

      if (preferredCategories.isNotEmpty) {
        bool match = false;
        for (final cat in preferredCategories) {
          if (categories.any((c) => c.toLowerCase().contains(cat.toLowerCase()))) {
            match = true;
            break;
          }
        }
        if (!match) return false;
      }

      if (preferredSeverity.isNotEmpty) {
        if (severity.isEmpty || !preferredSeverity.contains(severity.toLowerCase())) {
          return false;
        }
      }

      if (preferredRegions.isNotEmpty) {
        if (region.isEmpty || !preferredRegions.contains(region.toLowerCase())) {
          return false;
        }
      }

      if (preferredCounties.isNotEmpty) {
        // Include articles with no counties detected or generic entries
        if (counties.isEmpty) return true;
        bool hasGeneric = counties.any((c) =>
            c.toLowerCase().contains('multiple') ||
            c.toLowerCase().contains('all ') ||
            c.toLowerCase().contains('nationwide') ||
            c.toLowerCase().contains('various') ||
            c.toLowerCase().contains('unspecified'));
        if (hasGeneric) return true;

        bool match = false;
        for (final county in preferredCounties) {
          if (counties.any((c) => c.toLowerCase().contains(county.toLowerCase()))) {
            match = true;
            break;
          }
        }
        if (!match) return false;
      }

      if (preferredPlatforms.isNotEmpty && platform.isNotEmpty) {
        if (!preferredPlatforms.contains(platform.toLowerCase())) return false;
      }

      return true;
    }).toList();
  }

  Map<String, dynamic> toJson() => {
    'preferred_categories': preferredCategories,
    'preferred_severity': preferredSeverity,
    'preferred_regions': preferredRegions,
    'preferred_counties': preferredCounties,
    'preferred_platforms': preferredPlatforms,
  };

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      preferredCategories: (json['preferred_categories'] as List?)?.cast<String>() ?? [],
      preferredSeverity: (json['preferred_severity'] as List?)?.cast<String>() ?? [],
      preferredRegions: (json['preferred_regions'] as List?)?.cast<String>() ?? [],
      preferredCounties: (json['preferred_counties'] as List?)?.cast<String>() ?? [],
      preferredPlatforms: (json['preferred_platforms'] as List?)?.cast<String>() ?? [],
    );
  }
}

/// Available options — fetched from the backend API
class PreferenceOptions {
  static const List<String> categories = [
    'terrorism', 'cybersecurity', 'corruption', 'banditry', 'border_security',
    'organized_crime', 'ethnic_tension', 'election_integrity', 'radicalization',
    'fraud', 'drug_trafficking', 'human_rights', 'infrastructure', 'energy_mining',
    'environment', 'diplomacy', 'disinformation', 'food_security', 'public_health',
    'gender_violence', 'kidnapping', 'poaching', 'education', 'sports', 'tourism',
    'economics', 'governance', 'privacy', 'labor', 'land_disputes',
  ];

  static const List<String> severityLevels = ['critical', 'high', 'medium', 'low'];
  static const List<String> regions = ['local', 'regional', 'international'];
  static const List<String> platforms = ['twitter', 'reddit', 'telegram'];

  // All 47 official Kenyan counties
  static const List<String> counties = [
    'Baringo', 'Bomet', 'Bungoma', 'Busia', 'Embu', 'Garissa', 'Homa Bay',
    'Isiolo', 'Kajiado', 'Kakamega', 'Kericho', 'Kiambu', 'Kilifi', 'Kirinyaga',
    'Kisii', 'Kisumu', 'Kitui', 'Kwale', 'Laikipia', 'Lamu', 'Machakos',
    'Makueni', 'Mandera', 'Marsabit', 'Meru', 'Migori', 'Mombasa', "Murang'a",
    'Nairobi', 'Nakuru', 'Nandi', 'Narok', 'Nyamira', 'Nyandarua', 'Nyeri',
    'Samburu', 'Siaya', 'Taita-Taveta', 'Tana River', 'Tharaka-Nithi',
    'Trans Nzoia', 'Turkana', 'Uasin Gishu', 'Vihiga', 'Wajir', 'West Pokot',
  ];
}

/// Preferences service — loads/saves from the backend API (synced with web)
class PreferencesService extends StateNotifier<UserPreferences> {
  PreferencesService() : super(UserPreferences()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await ApiClient.instance.get('/preferences/');
      if (resp.statusCode == 200 && resp.data is Map) {
        final prefsData = resp.data['preferences'] as Map<String, dynamic>?;
        if (prefsData != null) {
          state = UserPreferences.fromJson(prefsData);
        }
      }
    } catch (_) {}
  }

  Future<void> save(UserPreferences prefs) async {
    state = prefs;
    try {
      await ApiClient.instance.put('/preferences/', data: prefs.toJson());
    } catch (_) {}
  }

  Future<void> clear() async {
    state = UserPreferences();
    try {
      await ApiClient.instance.put('/preferences/', data: UserPreferences().toJson());
    } catch (_) {}
  }
}

final preferencesProvider =
    StateNotifierProvider<PreferencesService, UserPreferences>((ref) {
  return PreferencesService();
});
