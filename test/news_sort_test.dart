import 'package:flutter_test/flutter_test.dart';

import 'package:falcon_intel_mobile/features/news/news_screen.dart';
import 'package:falcon_intel_mobile/models/article.dart';

Article _a(String id, {String? level, double? kenya, String? at}) =>
    Article(id: id, title: id, threatLevel: level, kenyaRelevance: kenya, publishedAt: at);

List<String> _ids(List<Article> list) => list.map((a) => a.id).toList();

void main() {
  final articles = [
    _a('old-low', level: 'low', kenya: 0.9, at: '2026-10-01T08:00:00Z'),
    _a('new-medium', level: 'medium', kenya: 0.5, at: '2026-10-02T09:00:00Z'),
    _a('mid-critical', level: 'critical', kenya: 70, at: '2026-10-01T20:00:00Z'), // 0–100 scale
    _a('no-date', level: 'high'),
    _a('newer-critical', level: 'critical', at: '2026-10-02T07:00:00Z'),
  ];

  test('newest first puts undated stories last', () {
    expect(_ids(sortArticles(articles, NewsSort.newest)),
        ['new-medium', 'newer-critical', 'mid-critical', 'old-low', 'no-date']);
  });

  test('most serious first, ties broken by newest', () {
    expect(_ids(sortArticles(articles, NewsSort.severity)),
        ['newer-critical', 'mid-critical', 'no-date', 'new-medium', 'old-low']);
  });

  test('most relevant to Kenya treats 0–1 and 0–100 alike; missing goes last', () {
    expect(_ids(sortArticles(articles, NewsSort.relevance)),
        ['old-low', 'mid-critical', 'new-medium', 'newer-critical', 'no-date']);
  });

  test('sorting does not change the original list', () {
    final before = _ids(articles);
    sortArticles(articles, NewsSort.severity);
    expect(_ids(articles), before);
  });
}
