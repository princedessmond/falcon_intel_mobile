import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/article.dart';

class ArticleDetailScreen extends StatefulWidget {
  final Article article;
  const ArticleDetailScreen({super.key, required this.article});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  bool _analyzing = false;
  AnalysisResult? _analysis;
  String? _analysisError;

  Future<void> _runAIAnalysis() async {
    setState(() {
      _analyzing = true;
      _analysisError = null;
    });

    try {
      // Build the best possible content from all available fields
      final article = widget.article;
      final summary = article.description ?? '';
      final content = article.content ?? '';
      // Use the longest available text for analysis
      final bestContent = content.isNotEmpty && content.length > summary.length
          ? content
          : summary.isNotEmpty
              ? summary
              : article.title;

      final resp = await ApiClient.instance.post('/ai/analyze', data: {
        'title': article.title,
        'summary': summary.isNotEmpty ? summary : bestContent,
        'content': bestContent,
        'source': article.source ?? '',
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
    final article = widget.article;
    final dt = DateTime.tryParse(article.publishedAt ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Article'),
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
            // Source + time
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (article.source != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(article.source!,
                        style: TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.w500)),
                  ),
                if (dt != null)
                  Text(timeago.format(dt),
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                if (article.category != null)
                  Text(article.category!,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            Text(article.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),

            // Synopsis
            if (article.description != null && article.description!.isNotEmpty) ...[
              Text('Synopsis',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(article.description!,
                  style: const TextStyle(fontSize: 15, height: 1.5, color: AppTheme.textPrimary)),
            ],
            if (article.content != null && article.content!.isNotEmpty && article.content != article.description) ...[
              const SizedBox(height: 16),
              Text(article.content!,
                  style: TextStyle(fontSize: 14, height: 1.5, color: AppTheme.textSecondary)),
            ],

            const SizedBox(height: 24),

            // AI Analysis button or results
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

            if (article.url != null) ...[
              const Divider(),
              const SizedBox(height: 16),
              Text('Source', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(article.url!,
                  style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
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
          // Header
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

          // Threat level — use Wrap instead of Row to prevent overflow
          if (analysis.threatLevel != null)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
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
          const SizedBox(height: 16),

          if (analysis.aiSummary != null && analysis.aiSummary!.isNotEmpty)
            _Section(title: 'AI Summary', content: analysis.aiSummary!),
          if (analysis.predictedImpact != null && analysis.predictedImpact!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Section(title: 'Predicted Impact', content: analysis.predictedImpact!),
          ],
          if (analysis.actionableIntelligence != null && analysis.actionableIntelligence!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Section(title: 'Actionable Intelligence', content: analysis.actionableIntelligence!),
          ],
          if (analysis.recommendedCountermeasures != null && analysis.recommendedCountermeasures!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Recommended Countermeasures',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
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
          if (analysis.categories != null && analysis.categories!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Categories', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: analysis.categories!.map((c) => Chip(
              label: Text(c, style: const TextStyle(fontSize: 11)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
            )).toList()),
          ],
          if (analysis.countiesDetected != null && analysis.countiesDetected!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Counties', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: analysis.countiesDetected!.map((c) => Chip(
              label: Text(c, style: const TextStyle(fontSize: 11)),
              avatar: const Icon(Icons.location_on, size: 14),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
            )).toList()),
          ],
          if (analysis.keyEntities != null && analysis.keyEntities!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Key Entities', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: analysis.keyEntities!.map((e) => Chip(
              label: Text(e, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
            )).toList()),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String content;
  const _Section({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(content, style: const TextStyle(fontSize: 14, height: 1.5, color: AppTheme.textPrimary)),
      ],
    );
  }
}
