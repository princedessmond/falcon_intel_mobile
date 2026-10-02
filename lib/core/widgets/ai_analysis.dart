import 'package:flutter/material.dart';

import '../../models/article.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// The AI analysis area of a detail screen: an invitation to run analysis,
/// a progress state, an error with retry, or the results.
class AiAnalysisSection extends StatelessWidget {
  final bool analyzing;
  final String? error;
  final AnalysisResult? analysis;
  final VoidCallback onAnalyze;
  const AiAnalysisSection({
    super.key,
    required this.analyzing,
    required this.error,
    required this.analysis,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    if (analyzing) {
      return Panel(
        borderColor: AppTheme.primaryColor.withValues(alpha: 0.35),
        child: Row(
          children: [
            SizedBox(width: 44, child: DotsLoader(color: AppTheme.primaryText, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analyzing with AI…',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text('This usually takes a few seconds',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // A re-run that failed keeps the previous result, with the error above it.
    if (analysis != null) {
      return Column(
        children: [
          if (error != null) ...[
            NoticeBanner.error('Couldn\'t run the analysis again: $error'),
            const SizedBox(height: 12),
          ],
          AnalysisCard(analysis: analysis!, onRerun: onAnalyze),
        ],
      );
    }

    return Column(
      children: [
        if (error != null) ...[
          NoticeBanner.error('AI analysis didn\'t work: $error'),
          const SizedBox(height: 12),
        ],
        Panel(
          borderColor: AppTheme.primaryColor.withValues(alpha: 0.45),
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryText, size: 20),
                  const SizedBox(width: 8),
                  Text('AI Analysis',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Get a plain-language summary, the likely impact and recommended actions.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: onAnalyze,
                icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                label: Text(error != null ? 'Try again' : 'Analyze with AI'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AnalysisCard extends StatelessWidget {
  final AnalysisResult analysis;

  /// Runs the analysis again (e.g. after the story was updated). Hidden when null.
  final VoidCallback? onRerun;
  const AnalysisCard({super.key, required this.analysis, this.onRerun});

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    bool has(String? s) => s != null && s.isNotEmpty;
    bool hasList(List<String>? l) => l != null && l.isNotEmpty;

    return Panel(
      borderColor: AppTheme.primaryColor.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryText, size: 20),
              const SizedBox(width: 8),
              Text('AI Analysis',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const Spacer(),
              if (onRerun != null)
                TextButton.icon(
                  onPressed: onRerun,
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Run again'),
                ),
            ],
          ),
          if (a.threatLevel != null || a.threatScore != null || a.confidenceScore != null) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (a.threatLevel != null)
                  Expanded(
                    child: _Stat(
                      label: 'Threat level',
                      child: SeverityPill(a.threatLevel!),
                    ),
                  ),
                if (a.threatScore != null)
                  Expanded(
                    child: _Stat(
                      label: 'Threat score',
                      // Same 0–1 / 0–100 handling as percentages, shown "out of 100".
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                          text: (percentLabel(a.threatScore) ?? '—').replaceAll('%', ''),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: ' / 100',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
                        ),
                      ])),
                    ),
                  ),
                if (a.confidenceScore != null)
                  Expanded(
                    child: _Stat(
                      label: 'AI confidence',
                      child: Text(percentLabel(a.confidenceScore) ?? '—',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ],
          if (has(a.aiSummary)) _TextSection(icon: Icons.notes_rounded, title: 'Summary', content: a.aiSummary!),
          if (has(a.predictedImpact))
            _TextSection(icon: Icons.trending_up_rounded, title: 'Possible impact', content: a.predictedImpact!),
          if (has(a.actionableIntelligence))
            _TextSection(
                icon: Icons.lightbulb_outline_rounded, title: 'What this means', content: a.actionableIntelligence!),
          if (hasList(a.recommendedCountermeasures)) ...[
            const SizedBox(height: 18),
            const _SectionTitle(icon: Icons.checklist_rounded, title: 'Recommended actions'),
            const SizedBox(height: 8),
            ...a.recommendedCountermeasures!.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(Icons.check_circle_rounded, size: 18, color: AppTheme.accentGreen),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child:
                            Text(c, textAlign: TextAlign.justify, style: const TextStyle(fontSize: 14.5, height: 1.45)),
                      ),
                    ],
                  ),
                )),
          ],
          if (hasList(a.categories)) _ChipSection(title: 'Topics', items: a.categories!.map(formatLabel).toList()),
          if (hasList(a.countiesDetected))
            _ChipSection(title: 'Counties', items: a.countiesDetected!, icon: Icons.place_outlined),
          if (hasList(a.keyEntities)) _ChipSection(title: 'People & organisations', items: a.keyEntities!),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final Widget child;
  const _Stat({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _TextSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  const _TextSection({required this.icon, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: icon, title: title),
          const SizedBox(height: 6),
          Text(content,
              textAlign: TextAlign.justify, style: TextStyle(fontSize: 15, height: 1.55, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

class _ChipSection extends StatelessWidget {
  final String title;
  final List<String> items;
  final IconData? icon;
  const _ChipSection({required this.title, required this.items, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items.map((t) => Pill(text: t, color: AppTheme.textSecondary, icon: icon, dense: true)).toList(),
          ),
        ],
      ),
    );
  }
}
