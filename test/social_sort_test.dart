import 'package:flutter_test/flutter_test.dart';

import 'package:falcon_intel_mobile/features/social/social_screen.dart';

void main() {
  final posts = <Map<String, dynamic>>[
    {'id': 'old-high-viral', 'severity': 'high', 'reach': 50000, 'kenya_relevance': 0.6, 'detected_at': '2026-10-01T08:00:00Z'},
    {'id': 'new-medium', 'severity': 'medium', 'score': 300, 'kenya_relevance': 95, 'detected_at': '2026-10-02T10:00:00Z'},
    {'id': 'critical', 'threat_level': 'critical', 'reach': 1200, 'detected_at': '2026-10-02T06:00:00Z'},
    {'id': 'undated-low', 'severity': 'low', 'num_comments': 87},
  ];
  List<String> ids(List<Map<String, dynamic>> l) => l.map((p) => p['id'] as String).toList();

  test('newest first, undated last', () {
    expect(ids(sortPosts(posts, SocialSort.newest)), ['new-medium', 'critical', 'old-high-viral', 'undated-low']);
  });

  test('most serious first reads severity or threat_level', () {
    expect(ids(sortPosts(posts, SocialSort.severity)), ['critical', 'old-high-viral', 'new-medium', 'undated-low']);
  });

  test('most seen ranks by reach, then upvotes, then comments', () {
    expect(ids(sortPosts(posts, SocialSort.engagement)), ['old-high-viral', 'critical', 'new-medium', 'undated-low']);
  });

  test('relevance treats 0–1 and 0–100 alike; missing goes last', () {
    expect(ids(sortPosts(posts, SocialSort.relevance)), ['new-medium', 'old-high-viral', 'critical', 'undated-low']);
  });
}
