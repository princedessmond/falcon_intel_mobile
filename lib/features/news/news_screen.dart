import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/auth_service.dart';
import '../../core/preferences/user_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../models/article.dart';
import 'article_detail_screen.dart';
import '../settings/preferences_screen.dart';

/// Time range options — matching the web portal (short label, long label, hours)
const _timeRanges = [
  ('24h', 'Last 24 hours', 24),
  ('48h', 'Last 2 days', 48),
  ('7d', 'Last 7 days', 168),
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

/// Severity chip on the News screen ('all' = no filter). Applied on top of
/// the loaded feed, so switching it is instant.
final newsSeverityProvider = StateProvider<String>((ref) => 'all');

const _severityFilters = ['all', 'critical', 'high', 'medium', 'low'];

/// How the News list is ordered. Done on the phone: the feed for the chosen
/// time range arrives in one response (no paging), so sorting is instant.
enum NewsSort {
  newest('Newest first', Icons.schedule_rounded),
  severity('Most serious first', Icons.warning_amber_rounded),
  relevance('Most relevant to Kenya', Icons.place_outlined);

  const NewsSort(this.label, this.icon);
  final String label;
  final IconData icon;
}

final newsSortProvider = StateProvider<NewsSort>((ref) => NewsSort.newest);

const _severityRank = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};

/// Returns a sorted copy of [articles]. Ties (and stories missing the sort
/// field) fall back to newest first; stories without a date go last.
List<Article> sortArticles(List<Article> articles, NewsSort sort) {
  DateTime? date(Article a) => DateTime.tryParse(a.publishedAt ?? '');
  int byNewest(Article a, Article b) {
    final da = date(a), db = date(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  }

  int bySeverity(Article a, Article b) {
    final ra = _severityRank[(a.threatLevel ?? '').toLowerCase()] ?? 4;
    final rb = _severityRank[(b.threatLevel ?? '').toLowerCase()] ?? 4;
    return ra != rb ? ra.compareTo(rb) : byNewest(a, b);
  }

  int byRelevance(Article a, Article b) {
    // Normalise 0–1 and 0–100 the same way the badges do.
    double rel(Article x) {
      final v = x.kenyaRelevance ?? -1;
      return v <= 1 ? v * 100 : v;
    }

    final c = rel(b).compareTo(rel(a));
    return c != 0 ? c : byNewest(a, b);
  }

  final sorted = List<Article>.of(articles);
  // List.sort isn't stable; break any remaining ties by original position.
  final index = {for (var i = 0; i < articles.length; i++) articles[i]: i};
  int compare(Article a, Article b) {
    final c = switch (sort) {
      NewsSort.newest => byNewest(a, b),
      NewsSort.severity => bySeverity(a, b),
      NewsSort.relevance => byRelevance(a, b),
    };
    return c != 0 ? c : index[a]!.compareTo(index[b]!);
  }

  sorted.sort(compare);
  return sorted;
}

void _showSortSheet(BuildContext context, WidgetRef ref) => showSortSheet<NewsSort>(
      context: context,
      title: 'Sort stories by',
      options: [for (final o in NewsSort.values) SortOption(o, o.label, o.icon)],
      current: ref.read(newsSortProvider),
      onSelected: (v) => ref.read(newsSortProvider.notifier).state = v,
    );

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

class NewsScreen extends ConsumerWidget {
  const NewsScreen({super.key});

  void _openPreferences(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PreferencesScreen()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(newsProvider);
    final prefs = ref.watch(preferencesProvider);
    final currentHours = ref.watch(timeRangeProvider);
    final severity = ref.watch(newsSeverityProvider);
    final sort = ref.watch(newsSortProvider);
    final firstName = ref.watch(authStateProvider.select((a) => a.name))?.split(' ').first;
    final rangeLabel = _timeRanges.firstWhere((t) => t.$3 == currentHours, orElse: () => _timeRanges.first).$2;

    return Scaffold(
      appBar: ScreenHeader(
        title: 'News',
        subtitle: firstName != null && firstName.isNotEmpty
            ? '${_greeting()}, $firstName'
            : 'Security news that matters to Kenya',
        actions: [
          HeaderAction(
            icon: Icons.tune_rounded,
            tooltip: 'My preferences',
            showDot: prefs.hasFilters,
            onPressed: () => _openPreferences(context),
          ),
          HeaderAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(newsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters live behind a summary bar, collapsed by default.
          CollapsibleFilters(
            summary: '$rangeLabel · ${severity == 'all' ? 'All severities' : '${formatLabel(severity)} only'}',
            activeCount: (currentHours != 24 ? 1 : 0) + (severity != 'all' ? 1 : 0),
            onReset: () {
              ref.read(timeRangeProvider.notifier).state = 24;
              ref.read(newsSeverityProvider.notifier).state = 'all';
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Time range filter
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: [
                        for (final (_, long, hours) in _timeRanges)
                          ButtonSegment(value: hours, label: Text(long.replaceFirst('Last ', ''))),
                      ],
                      selected: {currentHours},
                      onSelectionChanged: (s) => ref.read(timeRangeProvider.notifier).state = s.first,
                    ),
                  ),
                ),

                // Severity filter — counts come from the loaded feed
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: _severityFilters.map((value) {
                      final articles = newsAsync.valueOrNull?.articles;
                      final count = articles == null
                          ? null
                          : value == 'all'
                              ? articles.length
                              : articles.where((a) => (a.threatLevel ?? '').toLowerCase() == value).length;
                      final color = value == 'all' ? AppTheme.primaryText : AppTheme.severityColor(value);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(count == null ? formatLabel(value) : '${formatLabel(value)}  $count'),
                          avatar: value == 'all' ? null : Icon(AppTheme.severityIcon(value), size: 16, color: color),
                          selected: severity == value,
                          showCheckmark: false,
                          selectedColor: (value == 'all' ? AppTheme.primaryColor : color)
                              .withValues(alpha: AppTheme.isDark ? 0.28 : 0.14),
                          onSelected: (_) => ref.read(newsSeverityProvider.notifier).state = value,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          // Active preferences filter banner
          if (prefs.hasFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: NoticeBanner(
                icon: Icons.filter_alt_rounded,
                message: _buildFilterSummary(prefs),
                action: TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _openPreferences(context),
                  child: const Text('Edit'),
                ),
              ),
            ),

          // News list
          Expanded(
            child: newsAsync.when(
              skipLoadingOnRefresh: false,
              loading: () => const SkeletonList(variant: SkeletonVariant.article),
              error: (err, _) => RefreshIndicator(
                onRefresh: () async => ref.refresh(newsProvider),
                child: StateMessage.error(
                  error: err,
                  title: 'Couldn\'t load the news',
                  onRetry: () => ref.invalidate(newsProvider),
                ),
              ),
              data: (result) {
                final articles = sortArticles(
                  severity == 'all'
                      ? result.articles
                      : result.articles.where((a) => (a.threatLevel ?? '').toLowerCase() == severity).toList(),
                  sort,
                );

                if (result.articles.isNotEmpty && articles.isEmpty) {
                  return StateMessage(
                    icon: AppTheme.severityIcon(severity),
                    iconColor: AppTheme.severityColor(severity),
                    title: 'No $severity stories',
                    message: 'Nothing marked "$severity" in the ${rangeLabel.toLowerCase()}.',
                    actions: [
                      OutlinedButton(
                        onPressed: () => ref.read(newsSeverityProvider.notifier).state = 'all',
                        child: const Text('Show all stories'),
                      ),
                    ],
                  );
                }
                if (articles.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => ref.refresh(newsProvider),
                    child: _EmptyState(
                      hasFilters: result.hasFilters,
                      totalCount: result.totalCount,
                      rangeLabel: rangeLabel,
                      onWiden: currentHours < 168 ? () => ref.read(timeRangeProvider.notifier).state = 168 : null,
                      onAdjustPrefs: () => _openPreferences(context),
                      onClearFilters: () {
                        ref.read(preferencesProvider.notifier).clear();
                        ref.invalidate(newsProvider);
                      },
                    ),
                  );
                }
                // The first story with a photo is shown large at the top.
                final featuredIndex = articles.indexWhere((a) => _hasImage(a));
                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(newsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 0, bottom: 16),
                    itemCount: articles.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return SectionLabel(
                          '${articles.length} ${articles.length == 1 ? 'story' : 'stories'}',
                          padding: const EdgeInsets.fromLTRB(20, 0, 12, 2),
                          trailing: SortButton(
                            onPressed: () => _showSortSheet(context, ref),
                            activeLabel: sort == NewsSort.newest ? null : sort.label,
                          ),
                        );
                      }
                      final a = articles[i - 1];
                      return _ArticleCard(article: a, featured: i - 1 == featuredIndex && featuredIndex == 0);
                    },
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
      final n = prefs.preferredCategories.length;
      parts.add('$n ${n == 1 ? 'topic' : 'topics'}');
    }
    if (prefs.preferredSeverity.isNotEmpty) {
      parts.add(prefs.preferredSeverity.map(formatLabel).join('/'));
    }
    if (prefs.preferredRegions.isNotEmpty) {
      parts.add(prefs.preferredRegions.map(formatLabel).join('/'));
    }
    if (prefs.preferredCounties.isNotEmpty) {
      final n = prefs.preferredCounties.length;
      parts.add('$n ${n == 1 ? 'county' : 'counties'}');
    }
    if (parts.isEmpty) return 'Your preferences are filtering this feed';
    return 'Your preferences: ${parts.join(' · ')}';
  }
}

bool _hasImage(Article a) => a.imageUrl != null && a.imageUrl!.startsWith('http');

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final int totalCount;
  final String rangeLabel;
  final VoidCallback? onWiden;
  final VoidCallback onAdjustPrefs;
  final VoidCallback onClearFilters;
  const _EmptyState({
    required this.hasFilters,
    required this.totalCount,
    required this.rangeLabel,
    required this.onWiden,
    required this.onAdjustPrefs,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasFilters) {
      return StateMessage(
        icon: Icons.newspaper_rounded,
        title: 'No stories yet',
        message: 'Nothing was published in the ${rangeLabel.toLowerCase()}. Pull down to refresh.',
        actions: [
          if (onWiden != null) OutlinedButton(onPressed: onWiden, child: const Text('Show last 7 days')),
        ],
      );
    }

    return StateMessage(
      icon: Icons.filter_alt_off_rounded,
      iconColor: AppTheme.primaryText,
      title: 'No stories match your preferences',
      message: '$totalCount ${totalCount == 1 ? 'story is' : 'stories are'} available, '
          'but your filters are hiding them.',
      actions: [
        FilledButton(onPressed: onAdjustPrefs, child: const Text('Adjust preferences')),
        OutlinedButton(
          onPressed: onClearFilters,
          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentRed),
          child: const Text('Clear filters'),
        ),
      ],
    );
  }
}

/// Circle with the source's initial — a lightweight stand-in for a logo.
class _SourceAvatar extends StatelessWidget {
  final String source;
  const _SourceAvatar(this.source);

  static const _hues = [210.0, 160.0, 280.0, 25.0, 340.0, 190.0, 45.0];

  @override
  Widget build(BuildContext context) {
    final hue = _hues[source.codeUnits.fold<int>(0, (a, b) => a + b) % _hues.length];
    final color = HSLColor.fromAHSL(1, hue, 0.6, AppTheme.isDark ? 0.62 : 0.38).toColor();
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
      child: Text(source.isEmpty ? '?' : source[0].toUpperCase(),
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _NewsImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final double radius;
  const _NewsImage({required this.url, this.width, this.height, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
          width: width,
          height: height,
          color: AppTheme.surfaceHigh,
          alignment: Alignment.center,
          child: Icon(Icons.image_outlined, color: AppTheme.textMuted),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, __) => Shimmer(child: SkeletonBox(width: width, height: height ?? 84, radius: 0)),
        errorWidget: (_, __, ___) => fallback(),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final Article article;
  final bool featured;
  const _ArticleCard({required this.article, this.featured = false});

  @override
  Widget build(BuildContext context) {
    final level = article.threatLevel;
    final when = timeAgo(article.publishedAt);
    final hasImage = _hasImage(article);

    final sourceRow = Row(
      children: [
        if (article.source != null) ...[
          _SourceAvatar(article.source!),
          const SizedBox(width: 8),
          Flexible(
            child: Text(article.source!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
        if (article.source != null && when != null)
          Text('  ·  ', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        if (when != null) Text(when, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      ],
    );

    final badgeWrap = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (level != null) SeverityPill(level, dense: true),
        if (article.kenyaRelevance != null && article.kenyaRelevance! > 0)
          Pill(
            text: 'Kenya ${percentLabel(article.kenyaRelevance)}',
            color: AppTheme.accentGreen,
            icon: Icons.place_outlined,
            dense: true,
          ),
        if (article.categories.isNotEmpty)
          Pill(text: formatLabel(article.categories.first), color: AppTheme.textSecondary, dense: true),
        if (article.categories.length > 1)
          Pill(text: '+${article.categories.length - 1}', color: AppTheme.textMuted, dense: true),
      ],
    );
    final url = article.url;
    final badges = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: badgeWrap),
        if (url != null && url.startsWith('http')) OpenOriginalButton(url: url, tooltip: 'Open original article'),
      ],
    );

    final description = article.description != null && article.description!.isNotEmpty
        ? Text(article.description!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4))
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ArticleDetailScreen(article: article)),
        ),
        child: featured && hasImage
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _NewsImage(url: article.imageUrl!, radius: 0, width: double.infinity),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        sourceRow,
                        const SizedBox(height: 10),
                        Text(article.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, height: 1.3)),
                        if (description != null) ...[const SizedBox(height: 8), description],
                        const SizedBox(height: 12),
                        badges,
                      ],
                    ),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    sourceRow,
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(article.title,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16.5, height: 1.3)),
                              if (description != null && !hasImage) ...[const SizedBox(height: 6), description],
                            ],
                          ),
                        ),
                        if (hasImage) ...[
                          const SizedBox(width: 14),
                          _NewsImage(url: article.imageUrl!, width: 88, height: 88),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    badges,
                  ],
                ),
              ),
      ),
    );
  }
}
