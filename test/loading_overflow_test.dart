import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_approval/shared/widgets/common_widgets.dart';

/// The loading states put shimmer placeholders in the list region, which is an
/// `Expanded` (bounded height). A plain `Column` of fixed-height cards can't
/// scroll, so on a short viewport it overflowed the bottom ("BOTTOM OVERFLOWED
/// BY 70 PIXELS"). The fix is a `ListView`, which fills the bounded space and
/// scrolls instead.
///
/// These reproduce that exact layout at a deliberately short height.
void main() {
  // Header/chips stand-in above an Expanded list region, matching the screens.
  Widget host(Widget listRegion) => MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const SizedBox(height: 140), // header + tallies + chips
                Expanded(child: listRegion),
              ],
            ),
          ),
        ),
      );

  // Eight 94px placeholders = 752px, far taller than the short viewport's
  // list region, so the container must scroll rather than overflow.
  List<Widget> shimmers() => List.generate(
        8,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: ShimmerCard(height: 84),
        ),
      );

  testWidgets('ListView loading region does not overflow at a short height',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 380);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(ListView(children: shimmers())));
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
  });

  testWidgets('counterfactual: the old Column region overflowed', (tester) async {
    tester.view.physicalSize = const Size(1200, 380);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(Column(children: shimmers())));
    await tester.pump();

    // A Column in an Expanded can't scroll — this is the overflow the fix cures.
    expect(tester.takeException(), isNotNull);
  });

  // Even a tall viewport must stay clean (no accidental reverse regression).
  testWidgets('ListView loading region is clean at a tall height too',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(ListView(children: shimmers())));
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
  });
}
