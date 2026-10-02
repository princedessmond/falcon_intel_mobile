import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:falcon_intel_mobile/core/widgets/common.dart';

void main() {
  test('formatLabel turns API keys into readable labels', () {
    expect(formatLabel('border_security'), 'Border Security');
    expect(formatLabel('CRITICAL'), 'Critical');
    expect(formatLabel('social_media'), 'Social Media');
  });

  test('timeAgo ignores missing or invalid dates', () {
    expect(timeAgo(null), isNull);
    expect(timeAgo(''), isNull);
    expect(timeAgo('not a date'), isNull);
    expect(timeAgo(DateTime.now().toIso8601String()), isNotNull);
  });

  test('cleanHandle removes duplicated @ prefixes', () {
    expect(cleanHandle('@@ouma_neko'), 'ouma_neko');
    expect(cleanHandle('plain'), 'plain');
    expect(cleanHandle(null), isNull);
    expect(cleanHandle('@'), isNull);
  });

  test('dedupePostText shows a truncated title only once', () {
    const full = 'We don\'t need an @NCIC_Kenya that is reduced to a toothless bulldog, barking loudly';
    expect(dedupePostText('We don\'t need an @NCIC_Kenya that is reduced to a toothless', full), (full, null));
    expect(dedupePostText('Short title', 'Different details here'), ('Short title', 'Different details here'));
    expect(dedupePostText('Only title', ''), ('Only title', null));
  });

  test('percentLabel accepts 0–1 and 0–100 inputs without going over 100%', () {
    expect(percentLabel(0.4), '40%');
    expect(percentLabel(40), '40%');
    expect(percentLabel(87), '87%');
    expect(percentLabel(4000), '100%');
    expect(percentLabel(1), '100%');
    expect(percentLabel(null), isNull);
    expect(percentLabel('n/a'), isNull);
  });

  test('remainingText drops a repeated summary from the full text', () {
    expect(remainingText('Led by the Governor.', 'Led by the Governor. More details here.'), 'More details here.');
    expect(remainingText('Same text.', 'Same text.'), '');
    expect(remainingText('', 'Only body.'), 'Only body.');
    expect(remainingText('Summary.', 'Unrelated body.'), 'Unrelated body.');
    expect(remainingText('', 'Officials confirmed the... [2507 symbols]'), 'Officials confirmed the...');
    expect(remainingText('', 'Story text [+1234 chars]'), 'Story text');
  });

  test('scoreLabel and compactNumber read naturally', () {
    expect(scoreLabel(0.66), '66%');
    expect(compactNumber(48200), '48.2K');
    expect(compactNumber(87), '87');
    expect(hasCount(0), isFalse);
  });

  test('originalUrl completes Reddit permalinks', () {
    expect(originalUrl({'permalink': '/r/Kenya/comments/x/'}), 'https://www.reddit.com/r/Kenya/comments/x/');
    expect(originalUrl({'url': 'https://x.com/a/status/1'}), 'https://x.com/a/status/1');
    expect(originalUrl({'url': ''}), isNull);
  });

  test('friendlyError strips the Exception prefix', () {
    expect(friendlyError(Exception('Invalid email or password')), 'Invalid email or password');
  });

  testWidgets('SeverityPill shows a readable word and an icon', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SeverityPill('critical'))));
    expect(find.text('Critical'), findsOneWidget);
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);
  });

  testWidgets('CollapsibleFilters is hidden by default and opens on tap', (tester) async {
    var reset = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CollapsibleFilters(
          summary: 'Last 2 days · Critical only',
          activeCount: 2,
          onReset: () => reset = true,
          child: const Text('FILTER CONTROLS'),
        ),
      ),
    ));
    expect(find.text('Last 2 days · Critical only'), findsOneWidget);
    expect(find.text('Filters · 2'), findsOneWidget);
    expect(find.text('FILTER CONTROLS'), findsNothing);

    await tester.tap(find.text('Filters · 2'));
    await tester.pumpAndSettle();
    expect(find.text('FILTER CONTROLS'), findsOneWidget);
    await tester.tap(find.text('Reset filters'));
    expect(reset, isTrue);

    await tester.tap(find.text('Filters · 2'));
    await tester.pumpAndSettle();
    expect(find.text('FILTER CONTROLS'), findsNothing);
  });

  testWidgets('StateMessage renders title, message and actions', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StateMessage(
          icon: Icons.inbox,
          title: 'Nothing here',
          message: 'Pull to refresh',
          actions: [TextButton(onPressed: () => tapped = true, child: const Text('Retry'))],
        ),
      ),
    ));
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('Pull to refresh'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(tapped, isTrue);
  });
}
