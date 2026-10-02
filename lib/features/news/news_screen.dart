import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/preferences/user_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../models/article.dart';
import 'article_detail_screen.dart';
import '../settings/preferences_screen.dart';

/// Time range options — matching the web portal
const _timeRanges = [
  ('24h', 24),
  ('48h', 48),
  ('7d', 168),
];

/// The currently selected time range (in hours)
final timeRangeProvider = StateProvider<int>((ref) => 24);

/// Fetches news from the API and applies user preference filters.
final newsProvider = FutureProvider<NewsResult>((ref) async {
  final prefs = ref.watch(preferencesProvider);
  final hoursBack = ref.watch(timeRangeProvider);

  // Same endpoint as web portal: /api/news/nationwide/automatic?hours_back=N
  final resp = await ApiClient.instance.get(Endpoints.newsAutomatic, query: {
    'hours_back': hoursBack,
  });
  final data = resp.data;
  final articles = (data['news'] ?? data['articles'] ?? data['results'] ?? []) as List;
  var all = <Article>[];

  for (final j in articles) {
    try {
      all.add(Article.fromJson(j as Map<String, dynamic>));
    } catch (_) {}
  }

  var filtered = all;
  if (prefs.hasFilters) {
    filtered = prefs.filterArticles(all, (a) {
      return <String, dynamic>{
        'categories': a.categories,
        'severity': a.threatLevel,
        'region': a.region,
        'counties': a.countiesDetected,
        'platform': null,
      };
    });
  }

  return NewsResult(
    articles: filtered,
    totalCount: all.length,
    filteredCount: filtered.length,
    hasFilters: prefs.hasFilters,
  );
});

class NewsResult {
  final List<Article> articles;
  final int totalCount;
  final int filteredCount;
  final bool hasFilters;
  NewsResult({
    required this.articles,
    required this.totalCount,
    required this.filteredCount,
    required this.hasFilters,
  });
}

class NewsScreen extends ConsumerWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(newsProvider);
    final prefs = ref.watch(preferencesProvider);
    final currentHours = ref.watch(timeRangeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('News Intelligence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(newsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Time range filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _timeRanges.map((tr) {
                        final (label, hours) = tr;
                        final selected = currentHours == hours;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(label),
                            selected: selected,
                            onSelected: (_) {
                              ref.read(timeRangeProvider.notifier).state = hours;
                            },
                            selectedColor: AppTheme.primaryColor.withOpacity(0.3),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Active preferences filter banner
          if (prefs.hasFilters)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: AppTheme.primaryColor.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 14, color: AppTheme.primaryColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _buildFilterSummary(prefs),
                      style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PreferencesScreen()),
                    ),
                    child: const Text('Edit',
                        style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

          // News list
          Expanded(
            child: newsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => _ErrorState(error: err.toString(), onRetry: () => ref.refresh(newsProvider)),
              data: (result) {
                if (result.articles.isEmpty) {
                  return _EmptyState(
                    hasFilters: result.hasFilters,
                    totalCount: result.totalCount,
                    onAdjustPrefs: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PreferencesScreen()),
                    ),
                    onClearFilters: () {
                      ref.read(preferencesProvider.notifier).clear();
                      ref.refresh(newsProvider);
                    },
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(newsProvider),
                  child: ListView.builder(
                    itemCount: result.articles.length,
                    itemBuilder: (context, i) => _ArticleCard(article: result.articles[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _buildFilterSummary(UserPreferences prefs) {
    final parts = <String>[];
    if (prefs.preferredCategories.isNotEmpty) {
      parts.add('${prefs.preferredCategories.length} categories');
    }
    if (prefs.preferredSeverity.isNotEmpty) {
      parts.add(prefs.preferredSeverity.join('/'));
    }
    if (prefs.preferredRegions.isNotEmpty) {
      parts.add(prefs.preferredRegions.join('/'));
    }
    if (prefs.preferredCounties.isNotEmpty) {
      parts.add('${prefs.preferredCounties.length} counties');
    }
    return 'Filtered: ${parts.join(' · ')}';
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final int totalCount;
  final VoidCallback onAdjustPrefs;
  final VoidCallback onClearFilters;
  const _EmptyState({
    required this.hasFilters,
    required this.totalCount,
    required this.onAdjustPrefs,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasFilters) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.newspaper, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text('No articles in this time range',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.filter_alt_off, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text('No articles match your filters',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              '$totalCount articles available but none match your preferences',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: onAdjustPrefs,
                  child: const Text('Adjust Preferences'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: onClearFilters,
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentRed),
                  child: const Text('Clear Filters'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final Article article;
  const _ArticleCard({required this.article});

  @override
  Widget build(BuildContext context) {
    final severityColor = AppTheme.severityColor(article.threatLevel ?? 'low');

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(
          article.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.description != null && article.description!.isNotEmpty)
                Text(
                  article.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              const SizedBox(height: 6),
              if (article.categories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: article.categories.take(4).map((cat) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatCategory(cat),
                          style: TextStyle(color: AppTheme.primaryColor, fontSize: 10),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (article.source != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: severityColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        article.source!,
                        style: TextStyle(color: severityColor, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  if (article.threatLevel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: severityColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        article.threatLevel!.toUpperCase(),
                        style: TextStyle(color: severityColor, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (article.publishedAt != null)
                    Text(
                      timeago.format(DateTime.tryParse(article.publishedAt!) ?? DateTime.now()),
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  if (article.kenyaRelevance != null && article.kenyaRelevance! > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, size: 12, color: AppTheme.accentGreen),
                        const SizedBox(width: 2),
                        Text(
                          'KE ${(article.kenyaRelevance! * 100).toInt()}%',
                          style: TextStyle(color: AppTheme.accentGreen, fontSize: 11),
                        ),
                      ],
                    ),
                  if (article.region != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        article.region!.toUpperCase(),
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 9),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailScreen(article: article),
          ),
        ),
      ),
    );
  }

  String _formatCategory(String cat) {
    return cat.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text('Failed to load news',
                style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text(error,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}