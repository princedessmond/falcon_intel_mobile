import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/preferences/user_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import 'social_detail_screen.dart';

/// Most posts the backend will return in one request (its `limit` maximum).
/// The endpoint has no time-range parameter, so the time filter below works
/// on the newest [socialFetchLimit] posts.
const socialFetchLimit = 200;

/// Time range options shown on the Social screen (label, hours) — same as News.
const _socialTimeRanges = [('24 hours', 24), ('2 days', 48), ('7 days', 168)];

/// When a post was detected, or null if it has no usable date.
DateTime? postDate(Map<String, dynamic> post) =>
    DateTime.tryParse((post['detected_at'] ?? post['discovered_at'] ?? post['posted_at'] ?? '').toString());

/// Posts detected within the last [hours]. Posts without a date are kept —
/// we can't tell their age, and hiding them would silently drop data.
List<Map<String, dynamic>> filterByAge(List<Map<String, dynamic>> posts, int hours, {DateTime? now}) {
  final cutoff = (now ?? DateTime.now()).subtract(Duration(hours: hours));
  return posts.where((p) {
    final d = postDate(p);
    return d == null || !d.isBefore(cutoff);
  }).toList();
}

/// How the Social list is ordered (done on the phone, like News).
enum SocialSort {
  newest('Newest first', Icons.schedule_rounded),
  severity('Most serious first', Icons.warning_amber_rounded),
  engagement('Most seen & discussed', Icons.trending_up_rounded),
  relevance('Most relevant to Kenya', Icons.place_outlined);

  const SocialSort(this.label, this.icon);
  final String label;
  final IconData icon;
}

const _postSeverityRank = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};

/// Returns a sorted copy of [posts]. Missing values sort last; ties fall back
/// to newest first, then to the original order.
List<Map<String, dynamic>> sortPosts(List<Map<String, dynamic>> posts, SocialSort sort) {
  num? n(dynamic v) => num.tryParse('${v ?? ''}');
  int byNewest(Map<String, dynamic> a, Map<String, dynamic> b) {
    final da = postDate(a), db = postDate(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  }

  // Higher first; posts without the value go last.
  int desc(num? a, num? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }

  int compareBy(Map<String, dynamic> a, Map<String, dynamic> b) {
    switch (sort) {
      case SocialSort.newest:
        return byNewest(a, b);
      case SocialSort.severity:
        int rank(Map<String, dynamic> p) =>
            _postSeverityRank[(p['severity'] ?? p['threat_level'] ?? '').toString().toLowerCase()] ?? 4;
        return rank(a).compareTo(rank(b));
      case SocialSort.engagement:
        // Reach first (how many saw it), then upvotes, then comments.
        for (final key in ['reach', 'score', 'num_comments']) {
          final c = desc(n(a[key]), n(b[key]));
          if (c != 0) return c;
        }
        return 0;
      case SocialSort.relevance:
        num? rel(Map<String, dynamic> p) {
          final v = n(p['kenya_relevance']);
          return v == null ? null : (v <= 1 ? v * 100 : v);
        }
        return desc(rel(a), rel(b));
    }
  }

  final index = {for (var i = 0; i < posts.length; i++) posts[i]: i};
  return List<Map<String, dynamic>>.of(posts)
    ..sort((a, b) {
      final c = compareBy(a, b);
      if (c != 0) return c;
      final t = byNewest(a, b);
      return t != 0 ? t : index[a]!.compareTo(index[b]!);
    });
}

class SocialResult {
  final List<Map<String, dynamic>> posts;

  /// True when the server returned its maximum, so older posts may exist
  /// beyond [oldestFetched] that the app can't request.
  final bool hitLimit;
  final DateTime? oldestFetched;
  const SocialResult({required this.posts, required this.hitLimit, this.oldestFetched});

  /// Whether the chosen range reaches further back than the posts we have.
  bool truncates(int hours) =>
      hitLimit && oldestFetched != null && oldestFetched!.isAfter(DateTime.now().subtract(Duration(hours: hours)));
}

/// Social findings provider — fetches threats and applies user preference filters
final socialFindingsProvider = FutureProvider.family<SocialResult, String>((ref, filterKey) async {
  // Parse filter key: "platform:severity" e.g. "twitter:critical" or "all:all"
  final parts = filterKey.split(':');
  final platform = parts.isNotEmpty && parts[0] != 'all' ? parts[0] : null;
  final severity = parts.length > 1 && parts[1] != 'all' ? parts[1] : null;

  // Also get user preferences
  final prefs = ref.watch(preferencesProvider);

  final query = <String, dynamic>{};
  if (platform != null) query['platform'] = platform;
  if (severity != null) query['severity'] = severity;
  query['limit'] = socialFetchLimit;

  final resp = await ApiClient.instance.get(Endpoints.socialThreats, query: query);
  final data = resp.data;
  final findings = (data['findings'] ?? data['threats'] ?? data['results'] ?? []) as List;
  final all = findings.cast<Map<String, dynamic>>();
  final dates = all.map(postDate).whereType<DateTime>();
  final oldest = dates.isEmpty ? null : dates.reduce((a, b) => a.isBefore(b) ? a : b);
  SocialResult result(List<Map<String, dynamic>> posts) =>
      SocialResult(posts: posts, hitLimit: all.length >= socialFetchLimit, oldestFetched: oldest);

  // Apply user preference filters (client-side)
  if (!prefs.hasFilters) return result(all);

  return result(prefs.filterArticles<Map<String, dynamic>>(
      all,
      (finding) => {
            'categories': finding['categories'] is List ? List<String>.from(finding['categories']) : [],
            'severity': finding['severity'] ?? finding['threat_level'],
            'region': finding['region'],
            'counties': finding['counties_mentioned'] is List ? List<String>.from(finding['counties_mentioned']) : [],
            'platform': finding['platform'],
          }));
});

class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> {
  String _platform = 'all';
  String _severity = 'all';
  int _hours = 24;
  SocialSort _sort = SocialSort.newest;

  void _openSort() => showSortSheet<SocialSort>(
        context: context,
        title: 'Sort posts by',
        options: [for (final o in SocialSort.values) SortOption(o, o.label, o.icon)],
        current: _sort,
        onSelected: (v) => setState(() => _sort = v),
      );

  static const _platforms = [
    ('All', 'all'),
    ('X / Twitter', 'twitter'),
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
      appBar: ScreenHeader(
        title: 'Social Media',
        subtitle: 'Worrying posts from X, Reddit & Telegram',
        actions: [
          HeaderAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(socialFindingsProvider(_filterKey)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters live behind a summary bar, collapsed by default.
          CollapsibleFilters(
            summary: [
              'Last ${_socialTimeRanges.firstWhere((t) => t.$2 == _hours).$1}',
              _platform == 'all' ? 'All platforms' : _platforms.firstWhere((p) => p.$2 == _platform).$1,
              _severity == 'all' ? 'All severities' : '${formatLabel(_severity)} only',
            ].join(' · '),
            activeCount: (_hours != 24 ? 1 : 0) + (_platform != 'all' ? 1 : 0) + (_severity != 'all' ? 1 : 0),
            onReset: () => setState(() {
              _hours = 24;
              _platform = 'all';
              _severity = 'all';
            }),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Time range — same choices as News
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: [
                        for (final (label, hours) in _socialTimeRanges) ButtonSegment(value: hours, label: Text(label))
                      ],
                      selected: {_hours},
                      onSelectionChanged: (s) => setState(() => _hours = s.first),
                    ),
                  ),
                ),
                // Platform filter
                _FilterRow(
                  label: 'Platform',
                  children: _platforms.map((p) {
                    final (label, value) = p;
                    return ChoiceChip(
                      label: Text(label),
                      avatar: value == 'all'
                          ? null
                          : Icon(_platformIcon(value), size: 16, color: AppTheme.platformColor(value)),
                      selected: _platform == value,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _platform = value),
                    );
                  }).toList(),
                ),
                // Severity filter
                _FilterRow(
                  label: 'Severity',
                  children: _severities.map((s) {
                    final (label, value) = s;
                    final color = value == 'all' ? AppTheme.primaryColor : AppTheme.severityColor(value);
                    return ChoiceChip(
                      label: Text(label),
                      avatar: value == 'all' ? null : Icon(AppTheme.severityIcon(value), size: 16, color: color),
                      selected: _severity == value,
                      showCheckmark: false,
                      selectedColor: color.withValues(alpha: 0.28),
                      onSelected: (_) => setState(() => _severity = value),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          findingsAsync.maybeWhen(
            data: (r) {
              final n = filterByAge(r.posts, _hours).length;
              return Column(
                children: [
                  if (r.truncates(_hours))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: NoticeBanner(
                        message: 'Showing the newest $socialFetchLimit posts, which go back to '
                            '${timeAgo(r.oldestFetched!.toIso8601String())}. Older posts from this period '
                            'can\'t be loaded in the app yet.',
                      ),
                    ),
                  if (n > 0)
                    SectionLabel(
                      '$n ${n == 1 ? 'post' : 'posts'} flagged',
                      padding: const EdgeInsets.fromLTRB(20, 2, 12, 0),
                      trailing: SortButton(
                        onPressed: _openSort,
                        activeLabel: _sort == SocialSort.newest ? null : _sort.label,
                      ),
                    ),
                ],
              );
            },
            orElse: () => const SizedBox(height: 8),
          ),
          // Findings list
          Expanded(
            child: findingsAsync.when(
              skipLoadingOnRefresh: false,
              loading: () => const SkeletonList(variant: SkeletonVariant.post),
              error: (err, _) => StateMessage.error(
                error: err,
                title: 'Couldn\'t load social media posts',
                onRetry: () => ref.refresh(socialFindingsProvider(_filterKey)),
              ),
              data: (result) {
                final findings = sortPosts(filterByAge(result.posts, _hours), _sort);
                if (result.posts.isNotEmpty && findings.isEmpty) {
                  final range = _socialTimeRanges.firstWhere((t) => t.$2 == _hours).$1;
                  return StateMessage(
                    icon: Icons.schedule_rounded,
                    title: 'No posts in the last $range',
                    message: 'Nothing matching these filters was flagged in this period.',
                    actions: [
                      if (_hours < 168)
                        OutlinedButton(
                            onPressed: () => setState(() => _hours = 168), child: const Text('Show last 7 days')),
                    ],
                  );
                }
                if (findings.isEmpty) {
                  final filtered = _platform != 'all' || _severity != 'all';
                  return RefreshIndicator(
                    onRefresh: () async => ref.refresh(socialFindingsProvider(_filterKey)),
                    child: StateMessage(
                      icon: Icons.forum_outlined,
                      title: filtered ? 'Nothing matches these filters' : 'No flagged posts right now',
                      message: filtered
                          ? 'Try a different platform or severity.'
                          : 'Posts that look like threats will appear here. Pull down to refresh.',
                      actions: [
                        if (filtered)
                          OutlinedButton(
                            onPressed: () => setState(() {
                              _platform = 'all';
                              _severity = 'all';
                            }),
                            child: const Text('Show everything'),
                          ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(socialFindingsProvider(_filterKey)),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
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

IconData _platformIcon(String platform) {
  switch (platform.toLowerCase()) {
    case 'twitter':
    case 'x':
      return Icons.alternate_email_rounded;
    case 'reddit':
      return Icons.forum_rounded;
    case 'telegram':
      return Icons.send_rounded;
    default:
      return Icons.public_rounded;
  }
}

/// Labelled, horizontally scrolling row of filter chips.
class _FilterRow extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _FilterRow({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child:
                Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          for (final c in children) Padding(padding: const EdgeInsets.only(right: 6), child: c),
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
    final platform = (finding['platform'] ?? finding['source'] ?? 'unknown').toString();
    final severity = (finding['severity'] ?? finding['threat_level'] ?? 'medium').toString();
    final sentiment = (finding['sentiment'] ?? 'neutral').toString();
    final title = (finding['title'] ?? 'Untitled').toString();
    final description = finding['description']?.toString() ?? '';
    final when = timeAgo((finding['detected_at'] ?? finding['discovered_at'] ?? finding['posted_at'])?.toString());
    final author = cleanHandle(finding['author']);
    final url = originalUrl(finding);
    // Posts often arrive with the title being a cut-off copy of the text —
    // show the fuller one once.
    final (postText, extraText) = dedupePostText(title, description);
    final platColor = AppTheme.platformColor(platform);
    final platformName = platform.toLowerCase() == 'twitter' ? 'X / Twitter' : formatLabel(platform);

    final engagement = <(IconData, String)>[
      if (hasCount(finding['num_comments']))
        (Icons.chat_bubble_outline_rounded, compactNumber(finding['num_comments'])),
      if (hasCount(finding['score'])) (Icons.arrow_upward_rounded, compactNumber(finding['score'])),
      if (hasCount(finding['reach'])) (Icons.visibility_outlined, compactNumber(finding['reach'])),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author header, like a social post
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: platColor.withValues(alpha: 0.14), shape: BoxShape.circle),
                    child: Icon(_platformIcon(platform), color: platColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(author != null ? '@$author' : platformName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
                        const SizedBox(height: 2),
                        Text([if (author != null) platformName, if (when != null) when].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  SeverityPill(severity, dense: true),
                ],
              ),
              const SizedBox(height: 12),
              Text(postText,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.4, color: AppTheme.textPrimary)),
              if (extraText != null) ...[
                const SizedBox(height: 6),
                Text(extraText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, height: 1.4, color: AppTheme.textSecondary)),
              ],
              const SizedBox(height: 10),
              // Engagement + tone + open original
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final (icon, value) in engagement) MetaText(icon: icon, text: value),
                        if (sentiment != 'neutral')
                          Pill(
                            text: '${formatLabel(sentiment)} tone',
                            color: _sentimentColor(sentiment),
                            icon: _sentimentIcon(sentiment),
                            dense: true,
                          ),
                        if (finding['is_viral'] == true)
                          Pill(
                              text: 'Viral',
                              color: AppTheme.accentRed,
                              icon: Icons.local_fire_department_rounded,
                              dense: true),
                      ],
                    ),
                  ),
                  if (url != null) OpenOriginalButton(url: url, tooltip: openOriginalLabel(platform)),
                ],
              ),
            ],
          ),
        ),
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

  IconData _sentimentIcon(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
        return Icons.sentiment_satisfied_rounded;
      case 'negative':
        return Icons.sentiment_dissatisfied_rounded;
      default:
        return Icons.sentiment_neutral_rounded;
    }
  }
}
