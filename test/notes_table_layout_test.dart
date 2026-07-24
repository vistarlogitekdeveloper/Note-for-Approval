import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_approval/features/notes/models/note.dart';
import 'package:note_approval/shared/widgets/status_pill.dart';

/// The notes table pinned its status column to 110px. With the cell's 16px
/// side padding that leaves 78px, and the "Approved" pill needs ~85 — a 7.1px
/// right overflow. The action column was pinned to 100px, which made "View →"
/// wrap onto two lines.
///
/// These render the same column recipe the screen uses and assert nothing
/// overflows at any status or viewport width.
void main() {
  // Mirrors _NotesTable.columnWidths.
  const columns = <int, TableColumnWidth>{
    0: IntrinsicColumnWidth(),
    1: FlexColumnWidth(2),
    2: FlexColumnWidth(3),
    3: IntrinsicColumnWidth(),
    4: IntrinsicColumnWidth(),
    5: IntrinsicColumnWidth(),
  };

  // Mirrors _NotesTable.columnWidths when an admin views all notes: a "Raised
  // By" intrinsic column is inserted after Note #.
  const columnsAll = <int, TableColumnWidth>{
    0: IntrinsicColumnWidth(), // Note #
    1: IntrinsicColumnWidth(), // Raised By
    2: FlexColumnWidth(2), // Purpose
    3: FlexColumnWidth(3), // Objective
    4: IntrinsicColumnWidth(), // Status
    5: IntrinsicColumnWidth(), // Date
    6: IntrinsicColumnWidth(), // Action
  };

  Widget cell(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: child,
      );

  Widget raisedByCell() => cell(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('Avinash Prataprao Jadhav',
              style: TextStyle(fontSize: 13), maxLines: 1),
          Text('avinash.jadhav1@vistarlogitek.com',
              style: TextStyle(fontSize: 11), maxLines: 1),
        ],
      ));

  Widget tableAll(NoteStatus status) => MaterialApp(
        home: Scaffold(
          body: Table(
            columnWidths: columnsAll,
            children: [
              TableRow(children: [
                cell(const Text('NOTE #')),
                cell(const Text('RAISED BY')),
                cell(const Text('PURPOSE')),
                cell(const Text('OBJECTIVE')),
                cell(const Text('STATUS')),
                cell(const Text('DATE')),
                cell(const Text('')),
              ]),
              TableRow(children: [
                cell(const Text('NFA-2026-0002',
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                raisedByCell(),
                cell(const Text('New Vendor Registration')),
                cell(const Text('obj details')),
                cell(StatusPill(status)),
                cell(const Text('18 Jul 2026')),
                cell(TextButton(onPressed: () {}, child: const Text('View →'))),
              ]),
            ],
          ),
        ),
      );

  Widget table(NoteStatus status) => MaterialApp(
        home: Scaffold(
          body: Table(
            columnWidths: columns,
            children: [
              TableRow(children: [
                cell(const Text('NOTE #')),
                cell(const Text('PURPOSE')),
                cell(const Text('OBJECTIVE')),
                cell(const Text('STATUS')),
                cell(const Text('DATE')),
                cell(const Text('')),
              ]),
              TableRow(children: [
                cell(const Text('NFA-2026-0002',
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                cell(const Text('test1')),
                cell(const Text('obj details')),
                cell(StatusPill(status)),
                cell(const Text('18 Jul 2026')),
                cell(TextButton(onPressed: () {}, child: const Text('View →'))),
              ]),
            ],
          ),
        ),
      );

  // Every status, because the pill's width varies by label and "Approved" is
  // the longest — the one that actually overflowed.
  for (final status in NoteStatus.values) {
    testWidgets('notes table fits the ${status.name} pill', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(table(status));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'overflow with the ${status.name} pill');
    });
  }

  for (final width in [900.0, 1024.0, 1280.0, 1536.0, 1920.0]) {
    testWidgets('notes table fits at ${width.toInt()}px wide', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(table(NoteStatus.approved));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the action label stays on one line', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(table(NoteStatus.approved));
    await tester.pumpAndSettle();

    // Two lines would make the painted text taller than a single line box.
    final text = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(TextButton),
        matching: find.text('View →'),
      ),
    );
    expect(text.size.height, lessThan(text.preferredLineHeight * 1.5),
        reason: '"View →" wrapped onto a second line');
  });

  // All-notes (admin) layout: the extra "Raised By" intrinsic column squeezes
  // the flex columns, so re-check the pill and viewport widths don't overflow.
  for (final status in NoteStatus.values) {
    testWidgets('all-notes table fits the ${status.name} pill', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(tableAll(status));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'overflow with Raised By + ${status.name} pill');
    });
  }

  for (final width in [900.0, 1024.0, 1280.0, 1536.0, 1920.0]) {
    testWidgets('all-notes table fits at ${width.toInt()}px wide',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(tableAll(NoteStatus.approved));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
