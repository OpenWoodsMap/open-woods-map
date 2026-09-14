import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_woods_map/ui/messages.dart';

/// A screen with a button per message, so a test can trigger them in sequence
/// the way a few quick actions would.
Widget host(List<String> messages) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              for (final message in messages)
                TextButton(
                  onPressed: () => showMessage(context, message),
                  child: Text('say $message'),
                ),
              TextButton(
                onPressed: () => showMessage(
                  context,
                  'with an action',
                  actionLabel: 'UNDO',
                  onAction: () {},
                ),
                child: const Text('say with action'),
              ),
            ],
          ),
        ),
      ),
    );

void main() {
  testWidgets('a message offers a visible way to get rid of it', (tester) async {
    await tester.pumpWidget(host(['first']));
    await tester.tap(find.text('say first'));
    await tester.pump();

    expect(find.text('first'), findsOneWidget);
    // Swiping worked before, but nothing said so, so messages read as stuck.
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  // The one that mattered: messages queued, so a few actions in a row left a
  // pile to dismiss one at a time, and the older ones were still offering to
  // undo work that had since been built on.
  testWidgets('a new message replaces the one on screen', (tester) async {
    await tester.pumpWidget(host(['first', 'second']));
    await tester.tap(find.text('say first'));
    await tester.pump();
    await tester.tap(find.text('say second'));
    await tester.pumpAndSettle();

    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing);
  });

  testWidgets('the close icon dismisses it', (tester) async {
    await tester.pumpWidget(host(['first']));
    await tester.tap(find.text('say first'));
    // Settled, not a single frame: mid-entrance the icon has not reached the
    // place a tap would land, and the tap misses.
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('first'), findsNothing);
  });

  testWidgets('an action sits alongside the close icon, not instead of it',
      (tester) async {
    await tester.pumpWidget(host(const []));
    await tester.tap(find.text('say with action'));
    await tester.pump();

    expect(find.widgetWithText(SnackBarAction, 'UNDO'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  // Land Info's buttons live in a modal bottom sheet, which is a route of its
  // own above the screen that owns the Scaffold. The message still has to appear.
  testWidgets('works from inside a modal bottom sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (sheet) => TextButton(
                  onPressed: () => showMessage(sheet, 'Coordinates copied'),
                  child: const Text('copy'),
                ),
              ),
              child: const Text('open sheet'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('copy'));
    await tester.pumpAndSettle();

    expect(find.text('Coordinates copied'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
