import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/preferences/user_preferences.dart';
import '../../core/theme/app_theme.dart';
import 'social_detail_screen.dart';

/// Social findings provider — fetches threats and applies user preference filters
final socialFindingsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, filterKey) async {
  // Parse filter key: "platform:severity" e.g. "twitter:critical" or "all:all"
  final parts = filterKey.split(':');
  final platform = parts.isNotEmpty && parts[0] != 'all' ? parts[0] : null;
  final severity = parts.length > 1 && parts[1] != 'all' ? parts[1] : null;

  // Also get user preferences
  final prefs = ref.watch(preferencesProvider);

  final query = <String, dynamic>{};
  if (platform != null) query['platform'] = platform;
  if (severity != null) query['severity'] = severity;
  query['limit'] = 100;

  final resp = await ApiClient.instance.get(Endpoints.socialThreats, query: query);
  final data = resp.data;
  final findings = (data['findings'] ?? data['threats'] ?? data['results'] ?? []) as List;
  final all = findings.cast<Map<String, dynamic>>();

  // Apply user preference filters (client-side)
  if (!prefs.hasFilters) return all;

  return prefs.filterArticles<Map<String, dynamic>>(all, (finding) => {
    'categories': finding['categories'] is List ? List<String>.from(finding['categories']) : [],
    'severity': finding['severity'] ?? finding['threat_level'],
    'region': finding['region'],
    'counties': finding['counties_mentioned'] is List
        ? List<String>.from(finding['counties_mentioned'])
        : [],
    'platform': finding['platform'],
  });
});

class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> {
  String _platform = 'all';
  String _severity = 'all';

  static const _platforms = [
    ('All', 'all'),
    ('Twitter', 'twitter'),
    ('Reddit', 'reddit'),
    ('Telegram', 'telegram'),
  ];

  static const _severities = [
    ('All', 'all'),
    ('Critical', 'critical'),
    ('High', 'high'),
    ('Medium', 'medium'),
    ('Low', 'low'),
  ];

  String get _filterKey => '$_platform:$_severity';

  @override
  Widget build(BuildContext context) {
    final findingsAsync = ref.watch(socialFindingsProvider(_filterKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Social Media Intel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(socialFindingsProvider(_filterKey)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Platform filter chips
          Container(
            padding: const EdgeInsets.only(left: 12, top: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _platforms.map((p) {
                  final (label, value) = p;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(label),
                      selected: _platform == value,
                      onSelected: (_) => setState(() => _platform = value),
                      selectedColor: AppTheme.primaryColor.withOpacity(0.3),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Severity filter chips
          Container(
            padding: const EdgeInsets.only(left: 12, bottom: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _severities.map((s) {
                  final (label, value) = s;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(label),
                      selected: _severity == value,
                      onSelected: (_) => setState(() => _severity = value),
                      selectedColor: value == 'all'
                          ? AppTheme.primaryColor.withOpacity(0.3)
                          : AppTheme.severityColor(value).withOpacity(0.3),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Findings list
          Expanded(
            child: findingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 48, color: AppTheme.textSecondary),
                      const SizedBox(height: 16),
                      Text('Failed to load findings',
                          style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      Text(err.toString().substring(0, err.toString().length > 150 ? 150 : err.toString().length),
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () =>
                            ref.refresh(socialFindingsProvider(_filterKey)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (findings) {
                if (findings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum_outlined, size: 48, color: AppTheme.textSecondary),
                        const SizedBox(height: 16),
                        Text('No findings for this filter',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: findings.length,
                  itemBuilder: (context, i) => _FindingCard(
                    finding: findings[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SocialDetailScreen(finding: findings[i]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FindingCard extends StatelessWidget {
  final Map<String, dynamic> finding;
  final VoidCallback onTap;
  const _FindingCard({required this.finding, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final platform = finding['platform'] ?? finding['source'] ?? 'unknown';
    final severity = finding['severity'] ?? finding['threat_level'] ?? 'medium';
    final sentiment = finding['sentiment'] ?? 'neutral';
    final title = finding['title'] ?? 'Untitled';
    final dt = DateTime.tryParse(
        finding['detected_at'] ?? finding['discovered_at'] ?? finding['posted_at'] ?? '');

    final sevColor = AppTheme.severityColor(severity);
    final platColor = AppTheme.platformColor(platform);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 4,
          decoration: BoxDecoration(
            color: sevColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _ChipBadge(text: platform.toUpperCase(), color: platColor),
                  _ChipBadge(text: severity.toUpperCase(), color: sevColor),
                  if (sentiment != null && sentiment.toString() != 'neutral')
                    _ChipBadge(text: sentiment.toString().toUpperCase(), color: _sentimentColor(sentiment.toString())),
                ],
              ),
              if (dt != null) ...[
                const SizedBox(height: 4),
                Text(timeago.format(dt),
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ],
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Color _sentimentColor(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
        return AppTheme.accentGreen;
      case 'negative':
        return AppTheme.accentRed;
      default:
        return AppTheme.textSecondary;
    }
  }
}

class _ChipBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _ChipBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
