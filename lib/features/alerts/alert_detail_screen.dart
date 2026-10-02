import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/theme/app_theme.dart';
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
        _analysisError = e.toString().replaceAll('Exception: ', '');
        _analyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final severity = alert['severity'] ?? 'medium';
    final source = alert['source'] ?? 'unknown';
    final sourceType = alert['source_type'] ?? '';
    final category = alert['category'] ?? '';
    final title = alert['title'] ?? 'Untitled Alert';
    final description = alert['description'] ?? '';
    final county = alert['county'];
    final status = alert['status'] ?? 'new';
    final indicators = alert['indicators'];
    final timestamp = alert['timestamp'] ?? alert['created_at'] ?? '';
    final dt = DateTime.tryParse(timestamp);

    final sevColor = AppTheme.severityColor(severity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badges row
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _Badge(text: severity.toUpperCase(), color: sevColor),
                _Badge(text: sourceType.toUpperCase(), color: AppTheme.platformColor(sourceType)),
                _Badge(text: source, color: AppTheme.textSecondary),
                if (category.isNotEmpty)
                  _Badge(text: category, color: AppTheme.primaryColor),
                if (county != null)
                  _Badge(text: county.toString(), color: AppTheme.accentGreen),
                _Badge(
                  text: status.toUpperCase(),
                  color: status == 'checked' ? AppTheme.accentGreen : AppTheme.accentAmber,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            Text(title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),

            // Time
            if (dt != null)
              Text(timeago.format(dt),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),

            const SizedBox(height: 16),

            // Description
            if (description.isNotEmpty) ...[
              Text('Synopsis',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(description,
                  style: const TextStyle(fontSize: 15, height: 1.5, color: AppTheme.textPrimary)),
            ],

            const SizedBox(height: 16),

            // Indicators
            if (indicators is List && (indicators as List).isNotEmpty) ...[
              Text('Indicators of Compromise',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: (indicators as List).map((ind) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(ind.toString(),
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppTheme.textSecondary)),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 24),

            // AI Analysis button
            if (_analysis == null && !_analyzing)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _runAIAnalysis,
                  icon: const Icon(Icons.psychology),
                  label: const Text('AI Analyze'),
                ),
              ),

            if (_analyzing)
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Analyzing with AI...', style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),

            if (_analysisError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentRed.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_analysisError!,
                        style: const TextStyle(color: AppTheme.accentRed, fontSize: 13))),
                  ],
                ),
              ),
            ],

            if (_analysis != null) ...[
              const SizedBox(height: 24),
              _AnalysisCard(analysis: _analysis!),
            ],

            const SizedBox(height: 32),

            // Mark checked button
            if (status != 'checked' && status != 'resolved')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final alertId = alert['id'] ?? alert['_id'] ?? '';
                    try {
                      await ApiClient.instance.put(Endpoints.alertsUpdateStatus,
                          data: {'alert_id': alertId, 'status': 'checked'});
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Alert marked as checked'),
                            backgroundColor: AppTheme.accentGreen,
                          ),
                        );
                        Navigator.pop(context, true);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Mark as Checked'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final AnalysisResult analysis;
  const _AnalysisCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text('AI Analysis',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              const Spacer(),
              if (analysis.aiModel != null)
                Flexible(
                  child: Text(analysis.aiModel!,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                      overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (analysis.threatLevel != null)
            Wrap(
              spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Threat Level:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.severityColor(analysis.threatLevel!).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(analysis.threatLevel!.toUpperCase(),
                      style: TextStyle(color: AppTheme.severityColor(analysis.threatLevel!),
                          fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                if (analysis.threatScore != null)
                  Text('Score: ${analysis.threatScore!.toStringAsFixed(0)}',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                if (analysis.confidenceScore != null)
                  Text('Confidence: ${(analysis.confidenceScore! * 100).toInt()}%',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          if (analysis.aiSummary != null && analysis.aiSummary!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('AI Summary', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(analysis.aiSummary!, style: const TextStyle(fontSize: 14, height: 1.5)),
          ],
          if (analysis.predictedImpact != null && analysis.predictedImpact!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Predicted Impact', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(analysis.predictedImpact!, style: const TextStyle(fontSize: 14, height: 1.5)),
          ],
          if (analysis.actionableIntelligence != null && analysis.actionableIntelligence!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Actionable Intelligence', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(analysis.actionableIntelligence!, style: const TextStyle(fontSize: 14, height: 1.5)),
          ],
          if (analysis.recommendedCountermeasures != null && analysis.recommendedCountermeasures!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Recommended Countermeasures', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...analysis.recommendedCountermeasures!.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.accentGreen),
                  const SizedBox(width: 8),
                  Expanded(child: Text(c, style: const TextStyle(fontSize: 13, height: 1.4))),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}
