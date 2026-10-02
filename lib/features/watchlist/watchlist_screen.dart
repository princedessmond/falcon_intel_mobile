import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../models/finding.dart';

final watchlistProvider = FutureProvider<List<Watch>>((ref) async {
  final resp = await ApiClient.instance.get(Endpoints.watches, query: {'workbook_id': 'mobile'});
  final data = resp.data;
  final watches = (data is List ? data : (data['watches'] ?? data['results'] ?? [])) as List;
  return watches.map((j) => Watch.fromJson(j as Map<String, dynamic>)).toList();
});

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  final _queryController = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _addWatch() async {
    if (_queryController.text.trim().isEmpty) return;
    setState(() => _adding = true);
    try {
      await ApiClient.instance.post(Endpoints.watches, data: {
        'workbook_id': 'mobile',
        'query': _queryController.text.trim(),
        'sources': ['darkweb', 'news', 'social_media'],
        'search_mode': 'all',
        'match_mode': 'any',
        'live_fetch': true,
        'poll_interval_minutes': 15,
      });
      final added = _queryController.text.trim();
      _queryController.clear();
      ref.invalidate(watchlistProvider);
      if (mounted) {
        FocusScope.of(context).unfocus();
        showAppSnack(context, 'Now watching "$added"', success: true);
      }
    } catch (e) {
      if (mounted) showAppSnack(context, 'Couldn\'t add it. ${friendlyError(e)}', error: true);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _deleteWatch(String id) async {
    try {
      await ApiClient.instance.delete('${Endpoints.watches}/$id');
      ref.invalidate(watchlistProvider);
      if (mounted) showAppSnack(context, 'Removed from your watchlist');
    } catch (e) {
      if (mounted) showAppSnack(context, 'Couldn\'t remove it. ${friendlyError(e)}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final watchesAsync = ref.watch(watchlistProvider);

    return Scaffold(
      appBar: ScreenHeader(
        title: 'Watchlist',
        subtitle: 'Names, places and topics we track for you',
        actions: [
          HeaderAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(watchlistProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Add watch input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Watch a name, place or topic',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'We\'ll keep checking news, social media and the dark web, and alert you when it\'s mentioned.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _queryController,
                          enabled: !_adding,
                          textInputAction: TextInputAction.done,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Nairobi protests',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                          onSubmitted: (_) => _addWatch(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 54,
                        child: FilledButton(
                          onPressed: _adding ? null : _addWatch,
                          child: _adding
                              ? const DotsLoader(size: 18)
                              : const Text('Add'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          watchesAsync.maybeWhen(
            data: (w) => w.isEmpty
                ? const SizedBox.shrink()
                : SectionLabel(
                    'Watching ${w.length} ${w.length == 1 ? 'item' : 'items'}',
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          // Watch list
          Expanded(
            child: watchesAsync.when(
              skipLoadingOnRefresh: false,
              loading: () => const SkeletonList(count: 3, variant: SkeletonVariant.compact),
              error: (err, _) => StateMessage.error(
                error: err,
                title: 'Couldn\'t load your watchlist',
                onRetry: () => ref.invalidate(watchlistProvider),
              ),
              data: (watches) {
                if (watches.isEmpty) {
                  return const StateMessage(
                    icon: Icons.visibility_outlined,
                    title: 'Nothing on your watchlist yet',
                    message: 'Type a keyword above and tap Add to start monitoring it.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(watchlistProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    itemCount: watches.length,
                    itemBuilder: (context, i) => _WatchCard(
                      watch: watches[i],
                      onDelete: () => _deleteWatch(watches[i].id),
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

class _WatchCard extends StatelessWidget {
  final Watch watch;
  final VoidCallback onDelete;
  const _WatchCard({required this.watch, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final last = timeAgo(watch.lastTriggered);
    final color = watch.isActive ? AppTheme.accentGreen : AppTheme.textMuted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(watch.isActive ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(watch.query,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (!watch.isActive)
                        Pill(text: 'Paused', color: AppTheme.textMuted, dense: true)
                      else if (watch.liveFetch)
                        Pill(text: 'Live', color: AppTheme.accentGreen, icon: Icons.bolt_rounded, dense: true),
                      if (watch.pollInterval != null)
                        Text('Checks every ${watch.pollInterval} min',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
                      Text(last != null ? 'Last match $last' : 'No matches yet',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove',
              icon: Icon(Icons.delete_outline_rounded, color: AppTheme.textSecondary),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop watching?'),
        content: Text('You\'ll no longer get alerts for "${watch.query}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.dangerFill),
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
