import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/preferences/user_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  late UserPreferences _prefs;
  bool _loading = true;
  bool _saving = false;
  String _countyQuery = '';

  @override
  void initState() {
    super.initState();
    // Initialize from current state
    _prefs = ref.read(preferencesProvider);
    _loading = false;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(preferencesProvider.notifier).save(_prefs);
    if (!mounted) return;
    setState(() => _saving = false);
    _backToNews('Preferences saved — your feeds are now filtered', success: true);
  }

  Future<void> _clear() async {
    setState(() {
      _prefs = UserPreferences();
    });
    await ref.read(preferencesProvider.notifier).clear();
    if (mounted) _backToNews('Preferences cleared — showing everything');
  }

  /// Close this screen and land on the News feed so the user immediately sees
  /// the effect of their new preferences.
  void _backToNews(String message, {bool success = false}) {
    // The snackbar lives in the app-wide messenger, so it stays visible on News.
    showAppSnack(context, message, success: success);
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    goToNewsHome(router);
  }

  void _toggleCategory(String category) {
    setState(() {
      final cats = List<String>.from(_prefs.preferredCategories);
      if (cats.contains(category)) {
        cats.remove(category);
      } else {
        cats.add(category);
      }
      _prefs = _prefs.copyWith(preferredCategories: cats);
    });
  }

  void _toggleSeverity(String severity) {
    setState(() {
      final sevs = List<String>.from(_prefs.preferredSeverity);
      if (sevs.contains(severity)) {
        sevs.remove(severity);
      } else {
        sevs.add(severity);
      }
      _prefs = _prefs.copyWith(preferredSeverity: sevs);
    });
  }

  void _toggleRegion(String region) {
    setState(() {
      final regs = List<String>.from(_prefs.preferredRegions);
      if (regs.contains(region)) {
        regs.remove(region);
      } else {
        regs.add(region);
      }
      _prefs = _prefs.copyWith(preferredRegions: regs);
    });
  }

  void _toggleCounty(String county) {
    setState(() {
      final counties = List<String>.from(_prefs.preferredCounties);
      if (counties.contains(county)) {
        counties.remove(county);
      } else {
        counties.add(county);
      }
      _prefs = _prefs.copyWith(preferredCounties: counties);
    });
  }

  void _togglePlatform(String platform) {
    setState(() {
      final platforms = List<String>.from(_prefs.preferredPlatforms);
      if (platforms.contains(platform)) {
        platforms.remove(platform);
      } else {
        platforms.add(platform);
      }
      _prefs = _prefs.copyWith(preferredPlatforms: platforms);
    });
  }

  bool get _hasUnsavedChanges =>
      jsonEncode(_prefs.toJson()) != jsonEncode(ref.read(preferencesProvider).toJson());

  int get _selectedCount =>
      _prefs.preferredCategories.length +
      _prefs.preferredSeverity.length +
      _prefs.preferredRegions.length +
      _prefs.preferredCounties.length +
      _prefs.preferredPlatforms.length;

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all preferences?'),
        content: const Text('Your News and Social feeds will show everything again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.dangerFill),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (ok == true) await _clear();
  }

  Future<void> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have changes that haven\'t been saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep editing')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.accentRed),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final query = _countyQuery.trim().toLowerCase();
    final counties = query.isEmpty
        ? PreferenceOptions.counties
        : PreferenceOptions.counties.where((c) => c.toLowerCase().contains(query)).toList();

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Preferences'),
          actions: [
            TextButton(
              onPressed: _selectedCount == 0 && !_prefs.hasFilters ? null : _confirmClear,
              style: TextButton.styleFrom(foregroundColor: AppTheme.accentRed),
              child: const Text('Clear all'),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  const NoticeBanner(
                    message: 'Choose what matters to you. News and Social will only show matching items. '
                        'Leave a section empty to include everything.',
                  ),
                  const SizedBox(height: 16),

                  // Severity
                  _PrefSection(
                    title: 'Severity',
                    subtitle: 'How serious the threat is',
                    count: _prefs.preferredSeverity.length,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PreferenceOptions.severityLevels.map((sev) {
                        final color = AppTheme.severityColor(sev);
                        return FilterChip(
                          label: Text(formatLabel(sev)),
                          selected: _prefs.preferredSeverity.contains(sev),
                          onSelected: (_) => _toggleSeverity(sev),
                          selectedColor: color.withValues(alpha: 0.28),
                          avatar: Icon(AppTheme.severityIcon(sev), size: 16, color: color),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                  ),

                  // Categories
                  _PrefSection(
                    title: 'Topics',
                    subtitle: 'Kinds of threats to follow',
                    count: _prefs.preferredCategories.length,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PreferenceOptions.categories.map((cat) {
                        return FilterChip(
                          label: Text(formatLabel(cat)),
                          selected: _prefs.preferredCategories.contains(cat),
                          onSelected: (_) => _toggleCategory(cat),
                        );
                      }).toList(),
                    ),
                  ),

                  // Region
                  _PrefSection(
                    title: 'Regions',
                    subtitle: 'Where the story is from',
                    count: _prefs.preferredRegions.length,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PreferenceOptions.regions.map((reg) {
                        return FilterChip(
                          label: Text(formatLabel(reg)),
                          selected: _prefs.preferredRegions.contains(reg),
                          onSelected: (_) => _toggleRegion(reg),
                          avatar: const Icon(Icons.public, size: 16),
                        );
                      }).toList(),
                    ),
                  ),

                  // Social platforms
                  _PrefSection(
                    title: 'Social media platforms',
                    count: _prefs.preferredPlatforms.length,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PreferenceOptions.platforms.map((plat) {
                        return FilterChip(
                          label: Text(formatLabel(plat)),
                          selected: _prefs.preferredPlatforms.contains(plat),
                          onSelected: (_) => _togglePlatform(plat),
                          selectedColor: AppTheme.platformColor(plat).withValues(alpha: 0.28),
                          avatar: Icon(_platformIcon(plat), size: 16, color: AppTheme.platformColor(plat)),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                  ),

                  // Counties
                  _PrefSection(
                    title: 'Counties',
                    subtitle: 'Stories that mention no county are always shown',
                    count: _prefs.preferredCounties.length,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          onChanged: (v) => setState(() => _countyQuery = v),
                          decoration: const InputDecoration(
                            hintText: 'Search counties',
                            prefixIcon: Icon(Icons.search_rounded),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (counties.isEmpty)
                          Text('No county matches that search',
                              style: TextStyle(color: AppTheme.textSecondary))
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: counties.map((county) {
                              return FilterChip(
                                label: Text(county),
                                selected: _prefs.preferredCounties.contains(county),
                                onSelected: (_) => _toggleCounty(county),
                                selectedColor: AppTheme.accentGreen.withValues(alpha: 0.25),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Save button (sticky bottom)
            BottomActionBar(children: [
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const DotsLoader()
                    : Text(_selectedCount == 0
                        ? 'Save — show everything'
                        : 'Save $_selectedCount ${_selectedCount == 1 ? 'filter' : 'filters'}'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  IconData _platformIcon(String platform) {
    switch (platform) {
      case 'twitter':
        return Icons.alternate_email;
      case 'reddit':
        return Icons.forum_outlined;
      case 'telegram':
        return Icons.send_outlined;
      default:
        return Icons.public;
    }
  }
}

class _PrefSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int count;
  final Widget child;
  const _PrefSection({required this.title, required this.count, required this.child, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                ),
                Pill(
                  text: count == 0 ? 'All' : '$count selected',
                  color: count == 0 ? AppTheme.textMuted : AppTheme.primaryText,
                  dense: true,
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
