import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ai_analysis.dart';
import '../../core/widgets/common.dart';
import '../../models/article.dart';

class AlertDetailScreen extends StatefulWidget {
  final Map<String, dynamic> alert;
  const AlertDetailScreen({super.key, required this.alert});

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  bool _analyzing = false;
  AnalysisResult? _analysis;
  String? _analysisError;

  Future<void> _runAIAnalysis() async {
    setState(() {
      _analyzing = true;
      _analysisError = null;
    });

    try {
      final alert = widget.alert;
      final title = alert['title'] ?? '';
      final description = alert['description'] ?? '';

      final resp = await ApiClient.instance.post('/ai/analyze', data: {
        'title': title,
        'summary': description,
        'content': description,
        'source': alert['source'] ?? alert['source_type'] ?? '',
      });

      if (resp.statusCode == 200 && resp.data is Map) {
        final data = resp.data as Map;
        if (data['analysis'] != null && data['analysis'] is Map) {
          setState(() {
            _analysis = AnalysisResult.fromJson(data['analysis'] as Map<String, dynamic>);
            _analyzing = false;
          });
        } else {
          setState(() {
            _analysisError = 'No analysis data in response';
            _analyzing = false;
          });
        }
      } else {
        String errorMsg = 'Analysis failed (HTTP ${resp.statusCode})';
        if (resp.data is Map) {
          final detail = resp.data['detail'];
          if (detail is String) errorMsg = detail;
        }
        setState(() {
          _analysisError = errorMsg;
          _analyzing = false;
        });
      }
    } catch (e) {
      setState(() {
        _analysisError = friendlyError(e);
        _analyzing = false;
      });
    }
  }

  bool _checking = false;

  Future<void> _markChecked() async {
    final alert = widget.alert;
    final alertId = alert['id'] ?? alert['_id'] ?? '';
    setState(() => _checking = true);
    try {
      await ApiClient.instance.put(Endpoints.alertsUpdateStatus, data: {'alert_id': alertId, 'status': 'checked'});
      if (mounted) {
        showAppSnack(context, 'Alert marked as checked', success: true);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showAppSnack(context, 'Couldn\'t update the alert. ${friendlyError(e)}', error: true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final severity = (alert['severity'] ?? 'medium').toString();
    final source = (alert['source'] ?? 'unknown').toString();
    final sourceType = (alert['source_type'] ?? '').toString();
    final category = (alert['category'] ?? '').toString();
    final title = (alert['title'] ?? 'Untitled Alert').toString();
    final description = (alert['description'] ?? '').toString();
    final county = alert['county'];
    final status = (alert['status'] ?? 'new').toString();
    final indicators = alert['indicators'];
    final when = timeAgo((alert['timestamp'] ?? alert['created_at'])?.toString());
    final isDone = status == 'checked' || status == 'resolved';
    final url = originalUrl(alert);

    return Scaffold(
      appBar: AppBar(title: const Text('Alert')),
      bottomNavigationBar: isDone && url == null
          ? null
          : BottomActionBar(children: [
              if (url != null)
                OutlinedButton.icon(
                  onPressed: () => openExternalUrl(context, url),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(isDone ? openOriginalLabel(sourceType) : 'Open original'),
                ),
              if (!isDone)
                ElevatedButton(
                  onPressed: _checking ? null : _markChecked,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successFill,
                    disabledBackgroundColor: AppTheme.successFill.withValues(alpha: 0.7),
                  ),
                  child: _checking
                      ? const DotsLoader()
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded),
                            SizedBox(width: 8),
                            Flexible(child: Text('Mark checked', overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                ),
            ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            NoticeBanner(
              icon: isDone ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
              color: isDone ? AppTheme.accentGreen : AppTheme.accentAmber,
              message: isDone
                  ? 'This alert has been ${status == 'resolved' ? 'resolved' : 'checked'}.'
                  : 'This alert needs review. Read it, then tap "Mark checked".',
            ),
            const SizedBox(height: 16),

            // Badges row
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                SeverityPill(severity),
                if (sourceType.isNotEmpty)
                  Pill(text: formatLabel(sourceType), color: AppTheme.platformColor(sourceType)),
                if (category.isNotEmpty) Pill(text: formatLabel(category), color: AppTheme.primaryText),
                if (county != null)
                  Pill(text: county.toString(), color: AppTheme.accentGreen, icon: Icons.place_outlined),
              ],
            ),
            const SizedBox(height: 14),

            // Title
            Text(title,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.3, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),

            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                MetaText(icon: Icons.source_outlined, text: source, color: AppTheme.primaryText),
                if (when != null) MetaText(icon: Icons.schedule_rounded, text: when),
              ],
            ),
            const SizedBox(height: 20),

            // Description
            if (description.isNotEmpty) ...[
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('What happened'),
                    const SizedBox(height: 10),
                    Text(description,
                        textAlign: TextAlign.justify,
                        style: TextStyle(fontSize: 16, height: 1.6, color: AppTheme.textPrimary)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Indicators
            if (indicators is List && indicators.isNotEmpty) ...[
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Warning signs detected'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: indicators.map((ind) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceHigh,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: SelectableText(ind.toString(),
                              style: TextStyle(fontSize: 13, fontFamily: 'monospace', color: AppTheme.textPrimary)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 8),

            AiAnalysisSection(
              analyzing: _analyzing,
              error: _analysisError,
              analysis: _analysis,
              onAnalyze: _runAIAnalysis,
            ),
          ],
        ),
      ),
    );
  }
}
