import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../app.dart';
import 'alert_detail_screen.dart';

/// Fetches alerts — filtered to News and Social sources only (not darkweb).
/// Shared by the Alerts screen and the tab badge so their numbers always agree.
Future<List<Map<String, dynamic>>> fetchAppAlerts(String severity) async {
  // Same as web: /api/alerts?severity=X&status=all
  final query = <String, dynamic>{'status': 'all'};
  if (severity != 'all') query['severity'] = severity;
  final resp = await ApiClient.instance.get(Endpoints.alerts, query: query);
  final data = resp.data;
  final allAlerts = (data['alerts'] ?? data['results'] ?? []) as List;
  var alerts = allAlerts.cast<Map<String, dynamic>>();

  // Filter to only News and Social sources (same as web's source_type filtering)
  alerts = alerts.where((a) {
    final st = (a['source_type'] ?? a['type'] ?? '').toString().toLowerCase();
    return st == 'news' ||
        st == 'social_media' ||
        st == 'social' ||
        st == 'reddit' ||
        st == 'twitter' ||
        st == 'telegram';
  }).toList();

  return alerts;
}

/// Whether an alert still needs review (not checked or resolved).
bool isOpenAlert(Map<String, dynamic> a) => !['checked', 'resolved'].contains((a['status'] ?? 'new').toString());

final alertsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, severity) => fetchAppAlerts(severity),
);

/// Fetches alert count (for badge) — also filtered to news + social
final alertCountProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final resp = await ApiClient.instance.get(Endpoints.alertsCount);
  if (resp.data is Map) return resp.data;
  return {'count': 0, 'critical': 0, 'high': 0};
});

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  String _severity = 'all';

  static const _severities = [
    ('All', 'all'),
    ('Critical', 'critical'),
    ('High', 'high'),
    ('Medium', 'medium'),
    ('Low', 'low'),
  ];

  void _refreshAll() {
    ref.invalidate(alertsProvider(_severity));
    ref.invalidate(alertCountProvider);
    ref.invalidate(navAlertCountProvider);
  }

  /// Alerts with a "mark checked" request in flight (shows dots on the card).
  final Set<String> _checking = {};

  Future<void> _markChecked(Map<String, dynamic> alert) async {
    final alertId = alert['id'] ?? alert['_id'] ?? '';
    final key = alertId.toString();
    if (_checking.contains(key)) return;
    setState(() => _checking.add(key));
    try {
      await ApiClient.instance.put(Endpoints.alertsUpdateStatus, data: {'alert_id': alertId, 'status': 'checked'});
      _refreshAll();
      if (mounted) showAppSnack(context, 'Marked as checked', success: true);
    } catch (e) {
      if (mounted) showAppSnack(context, 'Couldn\'t update the alert. ${friendlyError(e)}', error: true);
    } finally {
      if (mounted) setState(() => _checking.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(alertsProvider(_severity));
    final countAsync = ref.watch(alertCountProvider);
    // Summary tiles count the alerts this screen actually lists (news + social),
    // so the numbers always match what the user can open.
    final allAlerts = ref.watch(alertsProvider('all')).valueOrNull;
    int openCount([String? sev]) => (allAlerts ?? const [])
        .where((a) => isOpenAlert(a) && (sev == null || (a['severity'] ?? '').toString().toLowerCase() == sev))
        .length;
    // Alerts from other sources (e.g. dark web) are counted by the server but
    // not listed here — tell the user rather than leave the numbers unexplained.
    final serverTotal = num.tryParse('${countAsync.valueOrNull?['count'] ?? 0}')?.toInt() ?? 0;
    final hiddenElsewhere = allAlerts == null ? 0 : serverTotal - openCount();

    return Scaffold(
      appBar: ScreenHeader(
        title: 'Alerts',
        subtitle: 'Things that need your attention',
        actions: [
          HeaderAction(icon: Icons.refresh_rounded, tooltip: 'Refresh', onPressed: _refreshAll),
        ],
      ),
      body: Column(
        children: [
          // Summary — tapping a tile filters the list
          Builder(
            builder: (context) {
              if (allAlerts == null) return const SizedBox.shrink();
              final total = openCount();
              final critical = openCount('critical');
              final high = openCount('high');
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _CountTile(
                        count: total,
                        label: 'Need review',
                        color: AppTheme.primaryText,
                        icon: Icons.notifications_active_rounded,
                        selected: _severity == 'all',
                        onTap: () => setState(() => _severity = 'all'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CountTile(
                        count: critical,
                        label: 'Critical',
                        color: AppTheme.accentRed,
                        icon: AppTheme.severityIcon('critical'),
                        selected: _severity == 'critical',
                        onTap: () => setState(() => _severity = 'critical'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CountTile(
                        count: high,
                        label: 'High',
                        color: AppTheme.accentOrange,
                        icon: AppTheme.severityIcon('high'),
                        selected: _severity == 'high',
                        onTap: () => setState(() => _severity = 'high'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (hiddenElsewhere > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: NoticeBanner(
                message: '$hiddenElsewhere more ${hiddenElsewhere == 1 ? 'alert comes' : 'alerts come'} from other '
                    'sources (like dark web monitoring). Open the Falcon Intel website to see '
                    '${hiddenElsewhere == 1 ? 'it' : 'them'}.',
              ),
            ),
          // Filters live behind a summary bar, collapsed by default.
          CollapsibleFilters(
            summary: _severity == 'all' ? 'All severities' : '${formatLabel(_severity)} alerts only',
            activeCount: _severity != 'all' ? 1 : 0,
            onReset: () => setState(() => _severity = 'all'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Severity filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Row(
                    children: _severities.map((s) {
                      final (label, value) = s;
                      final color = value == 'all' ? AppTheme.primaryColor : AppTheme.severityColor(value);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(label),
                          avatar: value == 'all' ? null : Icon(AppTheme.severityIcon(value), size: 16, color: color),
                          selected: _severity == value,
                          showCheckmark: false,
                          selectedColor: color.withValues(alpha: 0.28),
                          onSelected: (_) => setState(() => _severity = value),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          // Alerts list
          Expanded(
            child: alertsAsync.when(
              skipLoadingOnRefresh: false,
              loading: () => const SkeletonList(variant: SkeletonVariant.alert),
              error: (err, _) => StateMessage.error(
                error: err,
                title: 'Couldn\'t load alerts',
                onRetry: () => ref.invalidate(alertsProvider(_severity)),
              ),
              data: (alerts) {
                if (alerts.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => _refreshAll(),
                    child: StateMessage(
                      icon: Icons.verified_rounded,
                      iconColor: AppTheme.accentGreen,
                      title: _severity == 'all' ? 'All clear' : 'No $_severity alerts',
                      message: 'There are no ${_severity == "all" ? "" : "$_severity "}alerts from news or '
                          'social media right now. Pull down to check again.',
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _refreshAll(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    itemCount: alerts.length,
                    itemBuilder: (context, i) => _AlertCard(
                      alert: alerts[i],
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AlertDetailScreen(alert: alerts[i]),
                          ),
                        );
                        if (result == true) _refreshAll();
                      },
                      onMarkChecked: () => _markChecked(alerts[i]),
                      busy: _checking.contains((alerts[i]['id'] ?? alerts[i]['_id'] ?? '').toString()),
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

class _CountTile extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _CountTile({
    required this.count,
    required this.label,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.14) : AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? color.withValues(alpha: 0.6) : AppTheme.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const Spacer(),
                  Text('$count',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                ],
              ),
              const SizedBox(height: 4),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  final VoidCallback onTap;
  final VoidCallback onMarkChecked;
  final bool busy;
  const _AlertCard({required this.alert, required this.onTap, required this.onMarkChecked, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final severity = (alert['severity'] ?? 'medium').toString();
    final title = (alert['title'] ?? 'Untitled Alert').toString();
    final sourceType = (alert['source_type'] ?? '').toString();
    final category = alert['category'];
    final when = timeAgo((alert['timestamp'] ?? alert['created_at'])?.toString());
    final status = (alert['status'] ?? 'new').toString();
    final county = alert['county'];
    final isDone = status == 'checked' || status == 'resolved';
    final url = originalUrl(alert);

    return Opacity(
      opacity: isDone ? 0.7 : 1,
      child: SeverityCard(
        stripColor: AppTheme.severityColor(severity),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SeverityPill(severity, dense: true),
                const SizedBox(width: 8),
                if (sourceType.isNotEmpty)
                  Flexible(
                    child: Text(formatLabel(sourceType),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppTheme.platformColor(sourceType), fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                const Spacer(),
                if (when != null) Text(when, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
              ],
            ),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, height: 1.35),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            if (category != null || county != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (category != null)
                    Pill(text: formatLabel(category.toString()), color: AppTheme.primaryText, dense: true),
                  if (county != null)
                    Pill(text: county.toString(), color: AppTheme.accentGreen, icon: Icons.place_outlined, dense: true),
                ],
              ),
            ],
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 4),
            Row(
              children: [
                if (isDone)
                  MetaText(icon: Icons.check_circle_rounded, text: 'Checked', color: AppTheme.accentGreen)
                else
                  MetaText(icon: Icons.fiber_new_rounded, text: 'Needs review', color: AppTheme.accentAmber),
                const Spacer(),
                if (url != null) ...[
                  OpenOriginalButton(url: url, tooltip: openOriginalLabel(sourceType)),
                  const SizedBox(width: 4),
                ],
                if (!isDone && busy)
                  SizedBox(width: 120, height: 40, child: DotsLoader(color: AppTheme.accentGreen, size: 18))
                else if (!isDone)
                  TextButton.icon(
                    onPressed: onMarkChecked,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accentGreen,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Mark checked', style: TextStyle(fontSize: 14)),
                  )
                else
                  Text('View details',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
