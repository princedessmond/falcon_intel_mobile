import 'package:flutter_test/flutter_test.dart';

import 'package:falcon_intel_mobile/features/social/social_screen.dart';

void main() {
  final now = DateTime.utc(2026, 10, 2, 12);
  Map<String, dynamic> post(String id, int hoursAgo) =>
      {'id': id, 'detected_at': now.subtract(Duration(hours: hoursAgo)).toIso8601String()};

  final posts = [
    post('1h', 1),
    post('30h', 30),
    post('100h', 100),
    {'id': 'undated'},
    {'id': 'posted-at-field', 'posted_at': now.subtract(const Duration(hours: 2)).toIso8601String()},
  ];

  List<String> ids(List<Map<String, dynamic>> l) => l.map((p) => p['id'] as String).toList();

  test('filters by detection time and keeps undated posts', () {
    expect(ids(filterByAge(posts, 24, now: now)), ['1h', 'undated', 'posted-at-field']);
    expect(ids(filterByAge(posts, 48, now: now)), ['1h', '30h', 'undated', 'posted-at-field']);
    expect(ids(filterByAge(posts, 168, now: now)), ['1h', '30h', '100h', 'undated', 'posted-at-field']);
  });

  test('only flags truncation when the server cap was hit and the range reaches past it', () {
    final oldest = DateTime.now().subtract(const Duration(hours: 30));
    final capped = SocialResult(posts: const [], hitLimit: true, oldestFetched: oldest);
    expect(capped.truncates(24), isFalse); // the 200 posts already cover 24h
    expect(capped.truncates(168), isTrue); // 7 days needs older posts we can't fetch
    final notCapped = SocialResult(posts: const [], hitLimit: false, oldestFetched: oldest);
    expect(notCapped.truncates(168), isFalse);
  });
}
