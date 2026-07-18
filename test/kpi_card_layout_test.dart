import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_approval/shared/widgets/common_widgets.dart';

/// The KPI tiles used to size themselves with `childAspectRatio`, so their
/// height fell out of their width. At the widths where four columns still fit
/// but were narrow, every card overflowed its bottom by 16px.
///
/// These pump the real grid across the range that broke and assert nothing
/// overflows — a RenderFlex overflow is reported as a Flutter error, so any
/// recurrence fails here rather than in a screenshot.
void main() {
  // Mirrors kpiGridDelegate in dashboard_screen.dart.
  const delegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 230,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    mainAxisExtent: 124,
  );

  Widget grid() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GridView(
              gridDelegate: delegate,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Every card is tappable, so the chevron is present too — the
                // widest the header row ever gets.
                KpiCard(
                    label: 'Total Notes',
                    value: '1',
                    icon: Icons.description_outlined,
                    color: Colors.blue,
                    onTap: () {}),
                KpiCard(
                    label: 'Drafts',
                    value: '0',
                    icon: Icons.edit_note_rounded,
                    color: Colors.grey,
                    onTap: () {}),
                KpiCard(
                    label: 'Pending',
                    value: '0',
                    icon: Icons.pending_actions_outlined,
                    color: Colors.orange,
                    onTap: () {}),
                KpiCard(
                    label: 'Approved',
                    value: '1',
                    icon: Icons.check_circle_outline_rounded,
                    color: Colors.green,
                    onTap: () {}),
                KpiCard(
                    label: 'Rejected',
                    value: '0',
                    icon: Icons.cancel_outlined,
                    color: Colors.red,
                    onTap: () {}),
              ],
            ),
          ),
        ),
      );

  // 900–1100 is where the old childAspectRatio:1.6 produced ~133px tiles for
  // ~158px of content. 320 and 600 cover the phone/tablet column counts.
  for (final width in [320.0, 600.0, 760.0, 901.0, 1000.0, 1100.0, 1440.0, 1920.0]) {
    testWidgets('KPI grid does not overflow at ${width.toInt()}px wide',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(grid());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'a layout overflow was thrown at ${width}px');
    });
  }

  testWidgets('every card is tappable and reports its own tap', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tapped = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GridView(
          gridDelegate: delegate,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final label in ['Total Notes', 'Drafts', 'Pending', 'Approved', 'Rejected'])
              KpiCard(
                label: label,
                value: '0',
                icon: Icons.circle,
                color: Colors.blue,
                onTap: () => tapped.add(label),
              ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    for (final label in ['Total Notes', 'Drafts', 'Pending', 'Approved', 'Rejected']) {
      await tester.tap(find.text(label));
      await tester.pump();
    }
    expect(tapped,
        ['Total Notes', 'Drafts', 'Pending', 'Approved', 'Rejected']);
  });

  testWidgets('a card without onTap stays inert', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: KpiCard(
            label: 'Static',
            value: '3',
            icon: Icons.circle,
            color: Colors.blue),
      ),
    ));
    await tester.pumpAndSettle();
    // No chevron means nothing invites a tap that would do nothing.
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });

  testWidgets('a long value shrinks instead of overflowing', (tester) async {
    tester.view.physicalSize = const Size(901, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GridView(
          gridDelegate: delegate,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Far larger than any real count, to prove the card degrades by
            // scaling rather than by throwing.
            KpiCard(
                label: 'Total Notes',
                value: '9999999',
                icon: Icons.description_outlined,
                color: Colors.blue,
                onTap: () {}),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('9999999'), findsOneWidget);
  });
}
