import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_approval/core/theme/app_theme.dart';
import 'package:note_approval/features/notes/utils/note_blocks.dart';
import 'package:note_approval/features/notes/widgets/brief_note_field.dart';
import 'package:note_approval/features/notes/widgets/note_text_view.dart';

/// A range copied from Excel: tab-separated cells, CRLF rows, trailing newline,
/// and empty cells at the end of the last rows.
const excel = 'WALUJ To MYSORE PICK UP\t19500\t18000\t01/07/2026\r\n'
    'NARSAPURA To WALUJ 10MT\t24500\t22000\t06/08/2026\r\n'
    'WALUJ To NARSAPURA 12MT\t45500\t0\t\r\n';

void main() {
  group('note blocks', () {
    test('prose alone is one text block and saves unchanged', () {
      const v = 'Line one\n\nLine two';
      expect(parseNoteBlocks(v), [const NoteText(v)]);
      expect(serializeNoteBlocks(parseNoteBlocks(v)), v);
    });

    test('an Excel paste becomes a table framed by text', () {
      final blocks = pastedText(excel)!;
      expect(blocks, hasLength(1));
      final t = blocks.single as NoteTable;
      expect(t.rows, [
        ['WALUJ To MYSORE PICK UP', '19500', '18000', '01/07/2026'],
        ['NARSAPURA To WALUJ 10MT', '24500', '22000', '06/08/2026'],
        ['WALUJ To NARSAPURA 12MT', '45500', '0', ''],
      ]);
    });

    test('text, tables and text round-trip through the stored form', () {
      final blocks = normalizeBlocks([
        const NoteText('Please approve:'),
        NoteTable([
          ['a', 'b'],
          ['c', 'd'],
        ]),
        const NoteText(''),
        NoteTable([
          ['', 'Jan'],
          ['x', '1'],
        ]),
        const NoteText('Thanks'),
      ]);
      final stored = serializeNoteBlocks(blocks);
      expect(stored, 'Please approve:\na\tb\nc\td\n\n\tJan\nx\t1\nThanks');
      expect(parseNoteBlocks(stored), blocks);
    });

    test('a one-column table is kept as plain lines', () {
      expect(
        normalizeBlocks([
          NoteTable([
            ['a'],
            ['b'],
          ]),
        ]),
        [const NoteText('a\nb')],
      );
      expect(pastedText('no tabs here'), isNull);
    });

    test('trimNote keeps the tab of an empty first cell', () {
      expect(trimNote('\n  \tJan\nx\t1\n '), '\tJan\nx\t1');
    });
  });

  group('BriefNoteField', () {
    Future<TextEditingController> pump(WidgetTester tester, String initial) async {
      final ctrl = TextEditingController(text: initial);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              child: BriefNoteField(
                controller: ctrl,
                label: 'Brief Note *',
                hint: 'hint',
                maxChars: 5000,
              ),
            ),
          ),
        ),
      ));
      return ctrl;
    }

    testWidgets('a saved note with a table opens with a real table', (tester) async {
      await pump(tester, 'Rates:\n${excel.trim()}');
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('Table · 3 rows × 4 columns'), findsOneWidget);
      expect(find.text('NARSAPURA To WALUJ 10MT'), findsOneWidget);
    });

    testWidgets('tab-separated text pasted into the note turns into a table', (tester) async {
      final ctrl = await pump(tester, '');
      await tester.enterText(find.byType(TextField).first, 'Rates:\n$excel');
      await tester.pump();
      await tester.pump();
      expect(find.byType(Table), findsOneWidget);
      expect(
        ctrl.text,
        'Rates:\n'
        'WALUJ To MYSORE PICK UP\t19500\t18000\t01/07/2026\n'
        'NARSAPURA To WALUJ 10MT\t24500\t22000\t06/08/2026\n'
        'WALUJ To NARSAPURA 12MT\t45500\t0\t',
      );
    });

    testWidgets('editing a cell updates the note; removing the table merges the text',
        (tester) async {
      final ctrl = await pump(tester, 'Before\na\tb\nc\td\nAfter');
      await tester.enterText(find.widgetWithText(TextField, 'd'), 'D');
      await tester.pump();
      expect(ctrl.text, 'Before\na\tb\nc\tD\nAfter');

      await tester.tap(find.text('Remove table'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(Table), findsNothing);
      expect(ctrl.text, 'Before\nAfter');
    });
  });

  testWidgets('NoteTextView draws the table and leaves plain text alone', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Column(children: [
          const NoteTextView('just text', style: TextStyle()),
          NoteTextView('Rates:\n${excel.trim()}', style: const TextStyle()),
        ]),
      ),
    ));
    expect(find.text('just text'), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('45500'), findsOneWidget);
  });
}
