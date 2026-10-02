import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/article.dart';

class SocialDetailScreen extends StatefulWidget {
  final Map<String, dynamic> finding;
  const SocialDetailScreen({super.key, required this.finding});

  @override
  State<SocialDetailScreen> createState() => _SocialDetailScreenState();
}

class _SocialDetailScreenState extends State<SocialDetailScreen> {
  bool _analyzing = false;
  AnalysisResult? _analysis;
  String? _analysisError;

  Future<void> _runAIAnalysis() async {
    setState(() {
      _analyzing = true;
      _analysisError = null;
    });

    try {
      final finding = widget.finding;
      final title = finding['title'] ?? '';
      final description = finding['description'] ?? '';
      final content = finding['content'] ?? description;
      // Use the longest available text
      final bestContent = content.isNotEmpty && content.length > description.length
          ? content
          : description.isNotEmpty
              ? description
              : title;

      final resp = await ApiClient.instance.post('/ai/analyze', data: {
        'title': title,
        'summary': description.isNotEmpty ? description : bestContent,
        'content': bestContent,
        'source': finding['platform'] ?? finding['source'] ?? '',
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
          else if (detail is Map) errorMsg = detail['message']?.toString() ?? 'Analysis failed';
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
    final f = widget.finding;
    final platform = f['platform'] ?? f['source'] ?? 'unknown';
    final severity = f['severity'] ?? f['threat_level'] ?? 'medium';
    final sentiment = f['sentiment'] ?? 'neutral';
    final dt = DateTime.tryParse(f['detected_at'] ?? f['discovered_at'] ?? f['posted_at'] ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finding Detail'),
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
                _Badge(text: platform.toUpperCase(), color: AppTheme.platformColor(platform)),
                _Badge(text: severity.toUpperCase(), color: AppTheme.severityColor(severity)),
                _Badge(
                  text: sentiment.toUpperCase(),
                  color: _sentimentColor(sentiment),
                  icon: _sentimentIcon(sentiment),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            Text(f['title'] ?? 'Untitled',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),

            // Author + time
            if (f['author'] != null || dt != null)
              Row(
                children: [
                  if (f['author'] != null)
                    Text('@${f['author']}',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  if (f['author'] != null && dt != null)
                    Text(' · ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  if (dt != null)
                    Text(timeago.format(dt),
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            const SizedBox(height: 16),

            // Description
            if (f['description'] != null && f['description'].toString().isNotEmpty) ...[
              Text('Synopsis',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(f['description'],
                  style: const TextStyle(fontSize: 15, height: 1.5, color: AppTheme.textPrimary)),
            ],

            const SizedBox(height: 16),

            // Engagement stats
            _EngagementStats(finding: f),

            // Deep analysis metrics
            if (f['influence_score'] != null || f['bot_risk_score'] != null || f['is_viral'] == true) ...[
              const SizedBox(height: 16),
              _DeepAnalysisCard(finding: f),
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
                    const SizedBox(height: 4),
                    Text('This may take a few seconds',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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

            // Source URL
            if (f['url'] != null && f['url'].toString().isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 16),
              Text('Source', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(f['url'],
                  style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
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
      case 'neutral':
        return AppTheme.textSecondary;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _sentimentIcon(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
        return Icons.sentiment_satisfied;
      case 'negative':
        return Icons.sentiment_dissatisfied;
      default:
        return Icons.sentiment_neutral;
    }
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const _Badge({required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _EngagementStats extends StatelessWidget {
  final Map<String, dynamic> finding;
  const _EngagementStats({required this.finding});

  @override
  Widget build(BuildContext context) {
    final stats = <_StatItem>[
      if (finding['score'] != null)
        _StatItem(Icons.arrow_upward, 'Score', finding['score'].toString()),
      if (finding['num_comments'] != null)
        _StatItem(Icons.comment, 'Comments', finding['num_comments'].toString()),
      if (finding['reach'] != null)
        _StatItem(Icons.people, 'Reach', finding['reach'].toString()),
      if (finding['kenya_relevance'] != null)
        _StatItem(Icons.location_on, 'Kenya %', '${((finding['kenya_relevance'] ?? 0) * 100).toInt()}%'),
      if (finding['ai_confidence'] != null)
        _StatItem(Icons.analytics, 'AI Conf', '${finding['ai_confidence']}%'),
    ];

    if (stats.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: stats.map((s) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.icon, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text('${s.label}: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            Text(s.value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        )).toList(),
      ),
    );
  }
}

class _StatItem {
  final IconData icon;
  final String label;
  final String value;
  _StatItem(this.icon, this.label, this.value);
}

class _DeepAnalysisCard extends StatelessWidget {
  final Map<String, dynamic> finding;
  const _DeepAnalysisCard({required this.finding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentPurple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: AppTheme.accentPurple, size: 16),
              const SizedBox(width: 6),
              Text('Deep Analysis', style: TextStyle(color: AppTheme.accentPurple, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (finding['influence_score'] != null)
                _Metric('Influence', finding['influence_score'].toString()),
              if (finding['credibility_score'] != null)
                _Metric('Credibility', finding['credibility_score'].toString()),
              if (finding['bot_risk_score'] != null)
                _Metric('Bot Risk', finding['bot_risk_score'].toString()),
              if (finding['is_viral'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('VIRAL', style: TextStyle(color: AppTheme.accentRed, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              if (finding['narrative_cluster_label'] != null)
                _Metric('Cluster', finding['narrative_cluster_label'].toString()),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Text('$label: $value', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12));
  }
}

// Reuse the same _AnalysisCard from article_detail
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
