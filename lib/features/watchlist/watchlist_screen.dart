import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/theme/app_theme.dart';
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
      _queryController.clear();
      ref.refresh(watchlistProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _deleteWatch(String id) async {
    try {
      await ApiClient.instance.delete('${Endpoints.watches}/$id');
      ref.refresh(watchlistProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed'), backgroundColor: AppTheme.accentRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final watchesAsync = ref.watch(watchlistProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(watchlistProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Add watch input
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: const InputDecoration(
                      hintText: 'Add a watch query...',
                      prefixIcon: Icon(Icons.add),
                    ),
                    onSubmitted: (_) => _addWatch(),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _adding ? null : _addWatch,
                  icon: _adding
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle, color: AppTheme.primaryColor),
                ),
              ],
            ),
          ),
          // Watch list
          Expanded(
            child: watchesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Failed to load', style: TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(watchlistProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (watches) {
                if (watches.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility_outlined, size: 48, color: AppTheme.textSecondary),
                        const SizedBox(height: 16),
                        Text('No watches yet', style: TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 8),
                        Text('Add a query above to start monitoring',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: watches.length,
                  itemBuilder: (context, i) => _WatchCard(
                    watch: watches[i],
                    onDelete: () => _deleteWatch(watches[i].id),
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
    return Card(
      child: ListTile(
        leading: Icon(
          watch.isActive ? Icons.visibility : Icons.visibility_off,
          color: watch.isActive ? AppTheme.accentGreen : AppTheme.textSecondary,
        ),
        title: Text(watch.query, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              if (watch.liveFetch)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, size: 10, color: AppTheme.accentGreen),
                      const SizedBox(width: 2),
                      Text('Live', style: TextStyle(color: AppTheme.accentGreen, fontSize: 10)),
                    ],
                  ),
                ),
              if (watch.pollInterval != null) ...[
                const SizedBox(width: 8),
                Text(
                  'every ${watch.pollInterval}m',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
              if (watch.lastTriggered != null) ...[
                const SizedBox(width: 8),
                Text(
                  'last: ${timeago.format(DateTime.tryParse(watch.lastTriggered!) ?? DateTime.now())}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTheme.accentRed),
          onPressed: () => _confirmDelete(context),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete watch?'),
        content: Text('Remove "${watch.query}" from your watchlist?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Text('Delete', style: TextStyle(color: AppTheme.accentRed)),
          ),
        ],
      ),
    );
  }
}
