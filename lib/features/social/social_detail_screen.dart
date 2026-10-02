import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ai_analysis.dart';
import '../../core/widgets/common.dart';
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
          if (detail is String) {
            errorMsg = detail;
          } else if (detail is Map) errorMsg = detail['message']?.toString() ?? 'Analysis failed';
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

  @override
  Widget build(BuildContext context) {
    final f = widget.finding;
    final platform = (f['platform'] ?? f['source'] ?? 'unknown').toString();
    final severity = (f['severity'] ?? f['threat_level'] ?? 'medium').toString();
    final sentiment = (f['sentiment'] ?? 'neutral').toString();
    final when = timeAgo((f['detected_at'] ?? f['discovered_at'] ?? f['posted_at'])?.toString());
    final description = f['description']?.toString() ?? '';
    final author = cleanHandle(f['author']);
    // When the title is just the start of the post, show the full post as the
    // body instead of repeating it.
    final titleText = (f['title'] ?? 'Untitled').toString();
    final (_, extra) = dedupePostText(titleText, description);
    final isFullPost = description.isNotEmpty && extra == null;
    final url = originalUrl(f);

    return Scaffold(
      appBar: AppBar(title: const Text('Social Post')),
      bottomNavigationBar: url != null
          ? BottomActionBar(children: [
              OutlinedButton.icon(
                onPressed: () => openExternalUrl(context, url),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppTheme.primaryText,
                  side: BorderSide(color: AppTheme.primaryText.withValues(alpha: 0.6)),
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(openOriginalLabel(platform)),
              ),
            ])
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badges row
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                SeverityPill(severity),
                Pill(
                  text: platform.toLowerCase() == 'twitter' ? 'X / Twitter' : formatLabel(platform),
                  color: AppTheme.platformColor(platform),
                ),
                Pill(
                  text: '${formatLabel(sentiment)} tone',
                  color: _sentimentColor(sentiment),
                  icon: _sentimentIcon(sentiment),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Title
            Text((f['title'] ?? 'Untitled').toString(),
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.3, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),

            // Author + time
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                if (author != null)
                  MetaText(icon: Icons.person_outline_rounded, text: '@$author', color: AppTheme.primaryText),
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
                    SectionLabel(isFullPost ? 'Full post' : 'Summary'),
                    const SizedBox(height: 10),
                    Text(description,
                        textAlign: TextAlign.justify,
                        style: TextStyle(fontSize: 16, height: 1.6, color: AppTheme.textPrimary)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Engagement stats
            _EngagementStats(finding: f),

            // Deep analysis metrics
            if (f['influence_score'] != null || f['bot_risk_score'] != null || f['is_viral'] == true) ...[
              const SizedBox(height: 12),
              _DeepAnalysisCard(finding: f),
            ],

            const SizedBox(height: 20),

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

class _EngagementStats extends StatelessWidget {
  final Map<String, dynamic> finding;
  const _EngagementStats({required this.finding});

  @override
  Widget build(BuildContext context) {
    final stats = <_StatItem>[
      if (finding['score'] != null) _StatItem(Icons.arrow_upward_rounded, 'Score', compactNumber(finding['score'])),
      if (finding['num_comments'] != null)
        _StatItem(Icons.chat_bubble_outline_rounded, 'Comments', compactNumber(finding['num_comments'])),
      if (finding['reach'] != null) _StatItem(Icons.people_outline_rounded, 'Reach', compactNumber(finding['reach'])),
      if (percentLabel(finding['kenya_relevance']) != null)
        _StatItem(Icons.place_outlined, 'Kenya relevance', percentLabel(finding['kenya_relevance'])!),
      if (percentLabel(finding['ai_confidence']) != null)
        _StatItem(Icons.analytics_outlined, 'AI confidence', percentLabel(finding['ai_confidence'])!),
    ];

    if (stats.isEmpty) return const SizedBox.shrink();

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Engagement'),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 14,
              children: stats
                  .map((s) => SizedBox(
                        width: w,
                        child: Row(
                          children: [
                            Icon(s.icon, size: 18, color: AppTheme.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                                  Text(s.label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            );
          }),
        ],
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
    return Panel(
      color: AppTheme.accentPurple.withValues(alpha: 0.08),
      borderColor: AppTheme.accentPurple.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: AppTheme.accentPurple, size: 18),
              const SizedBox(width: 8),
              Text('Account & spread analysis',
                  style: TextStyle(color: AppTheme.accentPurple, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          if (finding['influence_score'] != null) _Metric('Influence', scoreLabel(finding['influence_score'])),
          if (finding['credibility_score'] != null) _Metric('Credibility', scoreLabel(finding['credibility_score'])),
          if (finding['bot_risk_score'] != null)
            _Metric('Bot risk (chance it\'s automated)', scoreLabel(finding['bot_risk_score'])),
          if (finding['narrative_cluster_label'] != null)
            _Metric('Narrative group', finding['narrative_cluster_label'].toString()),
          if (finding['is_viral'] == true) ...[
            const SizedBox(height: 6),
            Pill(text: 'Spreading fast (viral)', color: AppTheme.accentRed, icon: Icons.local_fire_department_rounded),
          ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}
