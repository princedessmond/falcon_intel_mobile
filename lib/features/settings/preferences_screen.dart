import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/preferences/user_preferences.dart';
import '../../core/theme/app_theme.dart';

class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  late UserPreferences _prefs;
  bool _loading = true;
  bool _saving = false;

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
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preferences saved — feeds will be filtered'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
  }

  Future<void> _clear() async {
    setState(() {
      _prefs = UserPreferences();
    });
    await ref.read(preferencesProvider.notifier).clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences cleared')),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Preferences'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.accentRed),
            onPressed: _clear,
            tooltip: 'Clear all',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Select your preferred categories, severity levels, regions, and counties. Your News and Social feeds will be filtered automatically.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Categories
                  _SectionTitle(title: 'OSINT Categories', count: _prefs.preferredCategories.length),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: PreferenceOptions.categories.map((cat) {
                      final selected = _prefs.preferredCategories.contains(cat);
                      return FilterChip(
                        label: Text(_formatCategory(cat), style: TextStyle(fontSize: 12)),
                        selected: selected,
                        onSelected: (_) => _toggleCategory(cat),
                        selectedColor: AppTheme.primaryColor.withOpacity(0.3),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Severity
                  _SectionTitle(title: 'Severity Levels', count: _prefs.preferredSeverity.length),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: PreferenceOptions.severityLevels.map((sev) {
                      final selected = _prefs.preferredSeverity.contains(sev);
                      return FilterChip(
                        label: Text(sev.toUpperCase(), style: TextStyle(fontSize: 12)),
                        selected: selected,
                        onSelected: (_) => _toggleSeverity(sev),
                        selectedColor: AppTheme.severityColor(sev).withOpacity(0.3),
                        avatar: Icon(Icons.warning, size: 14,
                            color: AppTheme.severityColor(sev)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Region
                  _SectionTitle(title: 'Regions', count: _prefs.preferredRegions.length),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: PreferenceOptions.regions.map((reg) {
                      final selected = _prefs.preferredRegions.contains(reg);
                      return FilterChip(
                        label: Text(reg[0].toUpperCase() + reg.substring(1),
                            style: const TextStyle(fontSize: 12)),
                        selected: selected,
                        onSelected: (_) => _toggleRegion(reg),
                        selectedColor: AppTheme.primaryColor.withOpacity(0.3),
                        avatar: const Icon(Icons.public, size: 14),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Social platforms
                  _SectionTitle(title: 'Social Media Platforms', count: _prefs.preferredPlatforms.length),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: PreferenceOptions.platforms.map((plat) {
                      final selected = _prefs.preferredPlatforms.contains(plat);
                      return FilterChip(
                        label: Text(plat[0].toUpperCase() + plat.substring(1),
                            style: const TextStyle(fontSize: 12)),
                        selected: selected,
                        onSelected: (_) => _togglePlatform(plat),
                        selectedColor: AppTheme.platformColor(plat).withOpacity(0.3),
                        avatar: Icon(_platformIcon(plat), size: 14,
                            color: AppTheme.platformColor(plat)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Counties
                  _SectionTitle(title: 'Counties', count: _prefs.preferredCounties.length),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: PreferenceOptions.counties.map((county) {
                      final selected = _prefs.preferredCounties.contains(county);
                      return FilterChip(
                        label: Text(county, style: const TextStyle(fontSize: 11)),
                        selected: selected,
                        onSelected: (_) => _toggleCounty(county),
                        selectedColor: AppTheme.accentGreen.withOpacity(0.3),
                        avatar: const Icon(Icons.location_on, size: 14),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          // Save button (sticky bottom)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              border: Border(top: BorderSide(color: AppTheme.darkCard)),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Saving...'),
                          ],
                        )
                      : const Text('Save Preferences'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCategory(String cat) {
    return cat.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;
  const _SectionTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            )),
        const SizedBox(width: 8),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('$count',
                style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11)),
          ),
      ],
    );
  }
}
