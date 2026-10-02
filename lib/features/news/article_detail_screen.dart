import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ai_analysis.dart';
import '../../core/widgets/common.dart';
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
  bool _showFullText = false;

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
    final article = widget.article;
    final when = timeAgo(article.publishedAt);
    final hasDescription = article.description != null && article.description!.isNotEmpty;
    // Feeds often repeat the summary at the start of the full text; show only
    // what's new so the reader doesn't see the same paragraph twice.
    final moreText = remainingText(article.description ?? '', article.content ?? '');
    final hasContent = moreText.isNotEmpty;
    final isLong = moreText.length > 360;

    final url = article.url;
    final hasUrl = url != null && url.startsWith('http');

    return Scaffold(
      appBar: AppBar(title: const Text('Story')),
      bottomNavigationBar: hasUrl
          ? BottomActionBar(children: [
              OutlinedButton.icon(
                onPressed: () => openExternalUrl(context, url),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppTheme.primaryText,
                  side: BorderSide(color: AppTheme.primaryText.withValues(alpha: 0.6)),
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open original article'),
              ),
            ])
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl != null && article.imageUrl!.startsWith('http')) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: article.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Shimmer(child: SkeletonBox(height: double.infinity, radius: 0)),
                    // No photo is better than a broken one.
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Badges
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (article.threatLevel != null) SeverityPill(article.threatLevel!),
                if (article.category != null) Pill(text: formatLabel(article.category!), color: AppTheme.primaryText),
                if (article.region != null)
                  Pill(text: formatLabel(article.region!), color: AppTheme.textSecondary, icon: Icons.public),
              ],
            ),
            const SizedBox(height: 14),

            // Title
            Text(article.title,
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, height: 1.25, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),

            // Source + time
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                if (article.source != null)
                  MetaText(icon: Icons.article_outlined, text: article.source!, color: AppTheme.primaryText),
                if (when != null) MetaText(icon: Icons.schedule_rounded, text: when),
                if (article.kenyaRelevance != null && article.kenyaRelevance! > 0)
                  MetaText(
                    icon: Icons.place_outlined,
                    text: 'Kenya relevance ${percentLabel(article.kenyaRelevance)}',
                    color: AppTheme.accentGreen,
                  ),
              ],
            ),

            if (article.countiesDetected.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: article.countiesDetected
                    .map((c) => Pill(text: c, color: AppTheme.accentGreen, icon: Icons.place_outlined, dense: true))
                    .toList(),
              ),
            ],

            const SizedBox(height: 20),

            // Synopsis
            if (hasDescription || hasContent)
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Summary'),
                    const SizedBox(height: 10),
                    if (hasDescription)
                      Text(article.description!,
                          textAlign: TextAlign.justify,
                          style: TextStyle(fontSize: 16, height: 1.6, color: AppTheme.textPrimary)),
                    if (hasContent) ...[
                      if (hasDescription) const SizedBox(height: 12),
                      Text(moreText,
                          textAlign: TextAlign.justify,
                          maxLines: isLong && !_showFullText ? 6 : null,
                          overflow: isLong && !_showFullText ? TextOverflow.ellipsis : null,
                          style: TextStyle(fontSize: 15, height: 1.6, color: AppTheme.textSecondary)),
                      if (isLong)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: TextButton.icon(
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                            onPressed: () => setState(() => _showFullText = !_showFullText),
                            icon: Icon(_showFullText ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                            label: Text(_showFullText ? 'Show less' : 'Show more'),
                          ),
                        ),
                    ],
                  ],
                ),
              ),

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
}
