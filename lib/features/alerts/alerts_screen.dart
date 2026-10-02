import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../app.dart';
import 'alert_detail_screen.dart';

/// Fetches alerts — filtered to News and Social sources only (not darkweb)
final alertsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, severity) async {
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
    return st == 'news' || st == 'social_media' || st == 'social' ||
        st == 'reddit' || st == 'twitter' || st == 'telegram';
  }).toList();

  return alerts;
});

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

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(alertsProvider(_severity));
    final countAsync = ref.watch(alertCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(alertsProvider(_severity));
              ref.invalidate(alertCountProvider);
              ref.invalidate(navAlertCountProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary banner
          countAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (data) {
              final total = data['count'] ?? 0;
              final critical = data['critical'] ?? 0;
              final high = data['high'] ?? 0;
              if (total == 0) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: (critical > 0 ? AppTheme.accentRed : AppTheme.accentAmber)
                    .withOpacity(0.15),
                child: Row(
                  children: [
                    Icon(Icons.notifications_active,
                        size: 18,
                        color: critical > 0 ? AppTheme.accentRed : AppTheme.accentAmber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('$total unchecked alerts',
                          style: TextStyle(
                            color: critical > 0 ? AppTheme.accentRed : AppTheme.accentAmber,
                            fontWeight: FontWeight.w600, fontSize: 13,
                          )),
                    ),
                    if (critical > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text('$critical critical',
                            style: const TextStyle(color: AppTheme.accentRed, fontSize: 12)),
                      ),
                    if (high > 0)
                      Text('$high high',
                          style: const TextStyle(color: AppTheme.accentAmber, fontSize: 12)),
                  ],
                ),
              );
            },
          ),
          // Severity filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          // Alerts list
          Expanded(
            child: alertsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, size: 48, color: AppTheme.textSecondary),
                      const SizedBox(height: 16),
                      Text('Failed to load alerts',
                          style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(alertsProvider(_severity)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (alerts) {
                if (alerts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, size: 48, color: AppTheme.accentGreen),
                        const SizedBox(height: 16),
                        Text('No ${_severity == "all" ? "" : _severity + " "}alerts from News or Social',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(alertsProvider(_severity)),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                        if (result == true) {
                          ref.invalidate(alertsProvider(_severity));
                          ref.invalidate(alertCountProvider);
                          ref.invalidate(navAlertCountProvider);
                        }
                      },
                      onMarkChecked: () async {
                        final alertId = alerts[i]['id'] ?? alerts[i]['_id'] ?? '';
                        try {
                          await ApiClient.instance.put(Endpoints.alertsUpdateStatus,
                              data: {'alert_id': alertId, 'status': 'checked'});
                          ref.invalidate(alertsProvider(_severity));
                          ref.invalidate(alertCountProvider);
                          ref.invalidate(navAlertCountProvider);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed: $e')),
                            );
                          }
                        }
                      },
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

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  final VoidCallback onTap;
  final VoidCallback onMarkChecked;
  const _AlertCard({required this.alert, required this.onTap, required this.onMarkChecked});

  @override
  Widget build(BuildContext context) {
    final severity = alert['severity'] ?? 'medium';
    final title = alert['title'] ?? 'Untitled Alert';
    final source = alert['source'] ?? alert['source_type'] ?? 'unknown';
    final sourceType = alert['source_type'] ?? '';
    final category = alert['category'];
    final timestamp = alert['timestamp'] ?? alert['created_at'] ?? '';
    final status = alert['status'] ?? 'new';
    final description = alert['description'] ?? '';
    final county = alert['county'];

    final sevColor = AppTheme.severityColor(severity);
    final dt = DateTime.tryParse(timestamp);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: severity bar + title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 44,
                    decoration: BoxDecoration(
                      color: sevColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _Badge(text: severity.toUpperCase(), color: sevColor),
                            if (sourceType.isNotEmpty)
                              _Badge(text: sourceType.toUpperCase(), color: AppTheme.platformColor(sourceType)),
                            if (category != null)
                              _Badge(text: category.toString(), color: AppTheme.primaryColor),
                            if (county != null)
                              _Badge(text: county.toString(), color: AppTheme.accentGreen),
                            if (dt != null)
                              Text(timeago.format(dt),
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
