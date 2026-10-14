import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../utils/note_blocks.dart';

/// Read-only note text: prose as written, and any pasted tables (see
/// note_blocks.dart) drawn as tables.
class NoteTextView extends StatelessWidget {
  const NoteTextView(this.value, {super.key, required this.style});

  final String value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final blocks = parseNoteBlocks(value);
    // Most notes are only prose — keep those exactly the Text they always were.
    if (blocks.length == 1) return Text(value, style: style);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in blocks)
          switch (b) {
            NoteText(:final text) when text.isEmpty => const SizedBox.shrink(),
            NoteText(:final text) => Text(text, style: style),
            NoteTable(:final rows) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Table(
                    defaultColumnWidth: const IntrinsicColumnWidth(),
                    border: TableBorder.all(color: context.c.line2, width: 1),
                    children: [
                      for (final r in rows)
                        TableRow(children: [
                          for (final cell in r)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Text(cell, style: style.copyWith(fontSize: 13.5, height: 1.35)),
                            ),
                        ]),
                    ],
                  ),
                ),
              ),
          },
      ],
    );
  }
}
