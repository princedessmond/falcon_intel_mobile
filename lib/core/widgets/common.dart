import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

// ── Text helpers ─────────────────────────────────────────────────────────

/// "border_security" → "Border Security"
String formatLabel(String raw) {
  return raw
      .replaceAll('_', ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

/// Relative time ("5 minutes ago"), or null if [raw] isn't a date.
String? timeAgo(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final dt = DateTime.tryParse(raw);
  return dt == null ? null : timeago.format(dt);
}

/// Turns technical exceptions into a sentence a non-technical user understands.
String friendlyError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The server is taking too long to respond. Please try again in a moment.';
      case DioExceptionType.connectionError:
        return 'Can\'t reach Falcon Intel. Check your internet connection and try again.';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode ?? 0;
        if (code == 401 || code == 403) {
          return 'Your session has expired. Please sign out and sign in again.';
        }
        if (code >= 500) return 'The server ran into a problem. Please try again shortly.';
        break;
      default:
        break;
    }
    if (error.error.toString().contains('SocketException')) {
      return 'Can\'t reach Falcon Intel. Check your internet connection and try again.';
    }
  }
  if (error is TimeoutException || error.toString().contains('SocketException')) {
    return 'Can\'t reach Falcon Intel. Check your internet connection and try again.';
  }
  if (error is TypeError || error is NoSuchMethodError) {
    return 'We received an unexpected response from the server. Please try again.';
  }
  final msg = error.toString().replaceAll('Exception: ', '');
  return msg.length > 160 ? '${msg.substring(0, 160)}…' : msg;
}

/// "@@name" / "@name" / "name" → "name" (we add a single @ when displaying).
String? cleanHandle(dynamic raw) {
  final s = raw?.toString().trim().replaceFirst(RegExp(r'^@+'), '');
  return s == null || s.isEmpty ? null : s;
}

bool hasCount(dynamic n) => (num.tryParse('$n') ?? 0) > 0;

/// Social titles are often a truncated copy of the post text. Returns the
/// text to show as the post body, plus any genuinely different extra text.
(String, String?) dedupePostText(String title, String description) {
  // Collapse line breaks/extra spaces so cards don't show blank lines.
  final t = title.replaceAll(RegExp(r'\s+'), ' ').trim();
  final d = description.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (d.isEmpty) return (t, null);
  String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final nt = norm(t), nd = norm(d);
  final probe = nt.length > 40 ? nt.substring(0, 40) : nt;
  if (nt.isEmpty || nd.startsWith(probe) || nt.startsWith(nd)) {
    return (d.length >= t.length ? d : t, null);
  }
  return (t, d);
}

/// The part of [full] that isn't already said by [summary]. Feeds often send
/// the full text starting with the summary paragraph (sometimes more than
/// once); this drops those leading repeats. Returns '' if nothing new remains.
String remainingText(String summary, String full) {
  // Feeds append truncation markers like "[2507 symbols]" or "[+1234 chars]".
  var rest = full
      .replaceAll(RegExp(r'\[\+?\d+\s*(symbols|chars|characters)\]', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final s = summary.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.isEmpty) return rest;
  if (rest == s || s.startsWith(rest)) return '';
  while (rest.startsWith(s)) {
    rest = rest.substring(s.length).trim();
  }
  return rest;
}

/// 48200 → "48.2K", 1250000 → "1.3M".
String compactNumber(dynamic n) {
  final v = num.tryParse('$n');
  if (v == null) return '$n';
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// Percentages arrive either as a 0–1 fraction (0.4) or already as 0–100
/// (40); both read as "40%". Out-of-range values are capped to 0–100%.
/// Returns null when [n] isn't a number.
String? percentLabel(dynamic n) {
  final v = num.tryParse('$n');
  if (v == null) return null;
  final pct = v <= 1 ? v * 100 : v;
  return '${pct.clamp(0, 100).round()}%';
}

/// Scores the backend sends as 0–1 fractions read better as percentages.
String scoreLabel(dynamic n) {
  final v = num.tryParse('$n');
  if (v == null) return '$n';
  if (v >= 0 && v <= 1) return '${(v * 100).round()}%';
  return compactNumber(v);
}

void showAppSnack(BuildContext context, String message, {bool success = false, bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          if (success || error) ...[
            Icon(success ? Icons.check_circle_rounded : Icons.error_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
        ],
      ),
      backgroundColor: success
          ? AppTheme.successFill
          : error
              ? AppTheme.dangerFill
              : null,
    ));
}

Future<void> openExternalUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  var ok = false;
  if (uri != null) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
  if (!ok && context.mounted) showAppSnack(context, 'Couldn\'t open the link', error: true);
}

/// Link to the original article/post in a finding or alert, if there is one.
/// Accepts the field names the backend uses across sources, and completes
/// Reddit permalinks that come back without a domain.
String? originalUrl(Map<String, dynamic> item) {
  for (final key in ['url', 'post_url', 'permalink', 'link', 'source_url', 'article_url']) {
    final v = item[key]?.toString().trim();
    if (v == null || v.isEmpty) continue;
    if (v.startsWith('http')) return v;
    if (v.startsWith('/r/')) return 'https://www.reddit.com$v';
  }
  return null;
}

/// "Open article" / "Open on X" etc. — what the open-original button says.
String openOriginalLabel(String? platform) {
  switch ((platform ?? '').toLowerCase()) {
    case 'twitter':
    case 'x':
      return 'Open on X / Twitter';
    case 'reddit':
      return 'Open on Reddit';
    case 'telegram':
      return 'Open on Telegram';
    case 'news':
    case '':
      return 'Open original article';
    default:
      return 'Open original post';
  }
}

/// Small round "open in browser" button for list cards.
class OpenOriginalButton extends StatelessWidget {
  final String url;
  final String tooltip;
  const OpenOriginalButton({super.key, required this.url, this.tooltip = 'Open original'});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.surfaceHigh,
        foregroundColor: AppTheme.primaryText,
      ),
      icon: const Icon(Icons.open_in_new_rounded, size: 18),
      onPressed: () => openExternalUrl(context, url),
    );
  }
}

// ── Badges ───────────────────────────────────────────────────────────────

/// Small rounded label used for sources, categories, statuses, etc.
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final bool dense;
  const Pill({super.key, required this.text, required this.color, this.icon, this.dense = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 9, vertical: dense ? 3 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: dense ? 11 : 12, fontWeight: FontWeight.w600, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Severity badge — colour + icon + word, so it reads without colour vision.
class SeverityPill extends StatelessWidget {
  final String severity;
  final bool dense;
  const SeverityPill(this.severity, {super.key, this.dense = false});

  @override
  Widget build(BuildContext context) {
    return Pill(
      text: formatLabel(severity),
      color: AppTheme.severityColor(severity),
      icon: AppTheme.severityIcon(severity),
      dense: dense,
    );
  }
}

/// Inline icon + text used for metadata such as source and time.
class MetaText extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const MetaText({super.key, required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppTheme.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

// ── Layout ───────────────────────────────────────────────────────────────

/// Small uppercase label above a section of content.
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  const SectionLabel(this.text, {super.key, this.trailing, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Bordered surface panel.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: borderColor ?? AppTheme.border),
      ),
      child: child,
    );
  }
}

/// Coloured banner with an icon — for errors, tips and notices.
class NoticeBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color? color;
  final Widget? action;
  const NoticeBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.color,
    this.action,
  }) : _isError = false;

  const NoticeBanner.error(this.message, {super.key, this.action})
      : icon = Icons.error_outline_rounded,
        color = null,
        _isError = true;

  final bool _isError;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? (_isError ? AppTheme.accentRed : AppTheme.primaryText);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: AppTheme.textPrimary, fontSize: 13.5, height: 1.4)),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Centered icon + title + explanation + optional actions. Used for empty and
/// error states. Scrollable so pull-to-refresh still works around it.
class StateMessage extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? message;
  final List<Widget> actions;
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.iconColor,
    this.actions = const [],
  });

  factory StateMessage.error(
      {required Object error, required VoidCallback onRetry, String title = 'Couldn\'t load this'}) {
    return StateMessage(
      icon: Icons.cloud_off_rounded,
      iconColor: AppTheme.accentAmber,
      title: title,
      message: friendlyError(error),
      actions: [
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = this.iconColor ?? AppTheme.textSecondary;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 36, color: iconColor),
                  ),
                  const SizedBox(height: 18),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  if (message != null) ...[
                    const SizedBox(height: 8),
                    Text(message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, height: 1.45, color: AppTheme.textSecondary)),
                  ],
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: actions),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Loading ──────────────────────────────────────────────────────────────

/// Three bouncing dots — the loading state inside buttons and inline actions.
class DotsLoader extends StatelessWidget {
  final Color? color;
  final double size;
  const DotsLoader({super.key, this.color, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return SpinKitThreeBounce(color: color ?? Colors.white, size: size);
  }
}

/// Sweeps a soft highlight across its child — wrap skeleton shapes in it.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppTheme.surfaceHigh;
    final highlight = AppTheme.shimmerHighlight;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value * 2.6 - 0.8; // sweep from off-left to off-right
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [base, highlight, base],
            stops: [(t - 0.3).clamp(0.0, 1.0), t.clamp(0.0, 1.0), (t + 0.3).clamp(0.0, 1.0)],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// A grey placeholder block (use inside [Shimmer]).
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;
  const SkeletonBox({super.key, this.width, this.height = 12, this.radius = 6, this.shape = BoxShape.rectangle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

enum SkeletonVariant { article, post, alert, compact }

/// Shimmering placeholder cards shaped like the content that is loading.
class SkeletonList extends StatelessWidget {
  final int count;
  final SkeletonVariant variant;
  const SkeletonList({super.key, this.count = 6, this.variant = SkeletonVariant.article});

  @override
  Widget build(BuildContext context) {
    // Shimmer goes inside each card so only the placeholder shapes glint,
    // not the card surface itself.
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemCount: count,
      itemBuilder: (_, i) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Shimmer(
            child: switch (variant) {
              SkeletonVariant.article => _articleSkeleton(i),
              SkeletonVariant.post => _postSkeleton(),
              SkeletonVariant.alert => _alertSkeleton(),
              SkeletonVariant.compact => _compactSkeleton(),
            },
          ),
        ),
      ),
    );
  }

  Widget _articleSkeleton(int i) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 120, height: 12),
              SizedBox(height: 12),
              SkeletonBox(height: 16),
              SizedBox(height: 8),
              SkeletonBox(width: 180, height: 16),
              SizedBox(height: 14),
              Row(children: [
                SkeletonBox(width: 64, height: 22, radius: 8),
                SizedBox(width: 6),
                SkeletonBox(width: 84, height: 22, radius: 8),
              ]),
            ],
          ),
        ),
        if (i.isEven) ...[
          const SizedBox(width: 14),
          const SkeletonBox(width: 84, height: 84, radius: 12),
        ],
      ],
    );
  }

  Widget _postSkeleton() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          SkeletonBox(width: 40, height: 40, shape: BoxShape.circle),
          SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkeletonBox(width: 120, height: 12),
            SizedBox(height: 8),
            SkeletonBox(width: 80, height: 10),
          ]),
        ]),
        SizedBox(height: 14),
        SkeletonBox(height: 14),
        SizedBox(height: 8),
        SkeletonBox(width: 220, height: 14),
        SizedBox(height: 14),
        SkeletonBox(width: 160, height: 12),
      ],
    );
  }

  Widget _alertSkeleton() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          SkeletonBox(width: 72, height: 22, radius: 8),
          Spacer(),
          SkeletonBox(width: 60, height: 10),
        ]),
        SizedBox(height: 12),
        SkeletonBox(height: 15),
        SizedBox(height: 8),
        SkeletonBox(width: 200, height: 15),
        SizedBox(height: 16),
        Row(children: [
          SkeletonBox(width: 100, height: 12),
          Spacer(),
          SkeletonBox(width: 110, height: 28, radius: 10),
        ]),
      ],
    );
  }

  Widget _compactSkeleton() {
    return const Row(
      children: [
        SkeletonBox(width: 42, height: 42, radius: 12),
        SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkeletonBox(width: 140, height: 14),
            SizedBox(height: 8),
            SkeletonBox(width: 200, height: 10),
          ]),
        ),
      ],
    );
  }
}

// ── Filters ──────────────────────────────────────────────────────────────

/// Filter controls tucked behind a slim summary bar. Collapsed by default so
/// the list gets the screen; the bar always says what's applied, and the
/// Filters button shows how many non-default filters are on.
class CollapsibleFilters extends StatefulWidget {
  /// Plain-language description of the current filters, e.g. "Last 24 hours · All severities".
  final String summary;

  /// How many filters differ from their defaults (shown on the button).
  final int activeCount;

  /// Restores every filter to its default; shown inside the panel when [activeCount] > 0.
  final VoidCallback? onReset;
  final Widget child;
  const CollapsibleFilters({
    super.key,
    required this.summary,
    required this.activeCount,
    required this.child,
    this.onReset,
  });

  @override
  State<CollapsibleFilters> createState() => _CollapsibleFiltersState();
}

class _CollapsibleFiltersState extends State<CollapsibleFilters> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.activeCount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Material(
            color: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: active ? AppTheme.primaryText.withValues(alpha: 0.5) : AppTheme.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                child: Row(
                  children: [
                    Icon(Icons.filter_list_rounded,
                        size: 20, color: active ? AppTheme.primaryText : AppTheme.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: _open ? 'Hide filters' : 'Show filters',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: active ? AppTheme.primaryColor : AppTheme.surfaceHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              active ? 'Filters · ${widget.activeCount}' : 'Filters',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: active ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 2),
                            AnimatedRotation(
                              turns: _open ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(Icons.expand_more_rounded,
                                  size: 18, color: active ? Colors.white : AppTheme.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    widget.child,
                    if (active && widget.onReset != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: TextButton.icon(
                            onPressed: widget.onReset,
                            icon: const Icon(Icons.restart_alt_rounded, size: 18),
                            label: const Text('Reset filters'),
                          ),
                        ),
                      ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

// ── Sorting ──────────────────────────────────────────────────────────────

/// One choice in a sort menu.
class SortOption<T> {
  final T value;
  final String label;
  final IconData icon;
  const SortOption(this.value, this.label, this.icon);
}

/// Bottom sheet listing sort choices, with the current one ticked.
void showSortSheet<T>({
  required BuildContext context,
  required String title,
  required List<SortOption<T>> options,
  required T current,
  required ValueChanged<T> onSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // cover the tab bar like a normal phone menu
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child:
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ),
            for (final option in options)
              ListTile(
                leading:
                    Icon(option.icon, color: option.value == current ? AppTheme.primaryText : AppTheme.textSecondary),
                title: Text(option.label,
                    style: TextStyle(fontWeight: option.value == current ? FontWeight.w700 : FontWeight.w500)),
                trailing: option.value == current ? Icon(Icons.check_rounded, color: AppTheme.primaryText) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  onSelected(option.value);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

/// Compact "Sort" text button for list headers. Shows the active order's
/// name when it isn't the default.
class SortButton extends StatelessWidget {
  final String? activeLabel;
  final VoidCallback onPressed;
  const SortButton({super.key, required this.onPressed, this.activeLabel});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
      icon: const Icon(Icons.sort_rounded, size: 18),
      label: Text(activeLabel ?? 'Sort'),
    );
  }
}

// ── Screen header ────────────────────────────────────────────────────────

/// Round icon button for screen headers, with an optional dot badge.
class HeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool showDot;
  const HeaderAction({super.key, required this.icon, required this.tooltip, this.onPressed, this.showDot = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: AppTheme.surface,
          shape: CircleBorder(side: BorderSide(color: AppTheme.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Badge(
                isLabelVisible: showDot,
                smallSize: 9,
                backgroundColor: AppTheme.primaryColor,
                alignment: const AlignmentDirectional(0.55, -0.55),
                child: Center(child: Icon(icon, size: 22, color: AppTheme.textPrimary)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Header for the top-level tabs: large title, a one-line subtitle that
/// explains the screen in plain words, and round action buttons.
class ScreenHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const ScreenHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  @override
  Size get preferredSize => const Size.fromHeight(84);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 84,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: AppTheme.textPrimary)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
          ],
        ],
      ),
      actions: [...actions, const SizedBox(width: 16)],
    );
  }
}

/// Card with a coloured severity strip on its left edge.
class SeverityCard extends StatelessWidget {
  final Color stripColor;
  final VoidCallback? onTap;
  final Widget child;
  final EdgeInsetsGeometry margin;
  const SeverityCard({
    super.key,
    required this.stripColor,
    required this.child,
    this.onTap,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: stripColor),
              Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 14), child: child)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Primary actions pinned to the bottom of a detail screen.
class BottomActionBar extends StatelessWidget {
  final List<Widget> children;
  const BottomActionBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: children[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tappable "open original source" row.
class SourceLinkTile extends StatelessWidget {
  final String url;
  final String title;
  const SourceLinkTile({super.key, required this.url, this.title = 'Read the original'});

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(url)?.host;
    return Material(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openExternalUrl(context, url),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.open_in_new_rounded, color: AppTheme.primaryText, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(host?.isNotEmpty == true ? host! : url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
