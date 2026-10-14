/// A brief note is stored as plain text, but it can carry tables pasted from
/// Excel, Teams or Word. A table is kept the way Excel itself puts one on the
/// clipboard: one row per line, cells separated by tabs. A run of consecutive
/// lines that each contain a tab is one table; every other line is prose, and a
/// blank line separates two tables that follow each other.
///
/// The backend reads the same shape to draw tables in the PDF and the e-mails
/// (`src/modules/note-for-approval/utils/noteText.js` in vistar_CRM), so the
/// two must agree on it. Nothing new is stored — a note without tables is
/// exactly the text it always was.
library;

sealed class NoteBlock {
  const NoteBlock();
}

class NoteText extends NoteBlock {
  const NoteText(this.text);
  final String text;

  @override
  bool operator ==(Object other) => other is NoteText && other.text == text;
  @override
  int get hashCode => text.hashCode;
  @override
  String toString() => 'NoteText(${text.replaceAll('\n', r'\n')})';
}

class NoteTable extends NoteBlock {
  /// Rows are squared up on construction, so every row has [columns] cells.
  NoteTable(List<List<String>> rows) : rows = _square(rows);
  final List<List<String>> rows;

  int get columns => rows.isEmpty ? 0 : rows.first.length;

  static List<List<String>> _square(List<List<String>> rows) {
    final width = rows.fold<int>(0, (w, r) => r.length > w ? r.length : w);
    return [
      for (final r in rows) [...r, for (var i = r.length; i < width; i++) ''],
    ];
  }

  String get _key => rows.map((r) => r.join('\t')).join('\n');

  @override
  bool operator ==(Object other) => other is NoteTable && other._key == _key;
  @override
  int get hashCode => _key.hashCode;
  @override
  String toString() => 'NoteTable($rows)';
}

/// A cell can never hold the characters that delimit cells and rows.
String cleanCell(String s) =>
    s.replaceAll(RegExp(r'[\t\r\n]+'), ' ').replaceAll(' ', ' ').trim();

/// Split stored note text into prose and tables, in order. The result always
/// alternates text / table / text … and starts and ends with text (possibly
/// empty), which is the shape the editor works in.
List<NoteBlock> parseNoteBlocks(String value) {
  final out = <NoteBlock>[];
  List<String>? prose;
  List<List<String>>? table;

  for (final line in value.replaceAll(RegExp(r'\r\n?'), '\n').split('\n')) {
    if (line.contains('\t')) {
      if (prose != null) {
        out.add(NoteText(prose.join('\n')));
        prose = null;
      }
      (table ??= []).add(line.split('\t').map(cleanCell).toList());
    } else {
      if (table != null) {
        out.add(NoteTable(table));
        table = null;
      }
      (prose ??= []).add(line);
    }
  }
  if (prose != null) out.add(NoteText(prose.join('\n')));
  if (table != null) out.add(NoteTable(table));
  return normalizeBlocks(out);
}

/// Merge neighbouring prose and put an (empty) text block before, between and
/// after tables, so a caret always has somewhere to go around a table.
///
/// A one-column "table" becomes plain lines: without a tab between cells it
/// could not be told apart from prose once saved.
List<NoteBlock> normalizeBlocks(List<NoteBlock> blocks) {
  final out = <NoteBlock>[];
  for (var b in blocks) {
    if (b is NoteTable && b.rows.isEmpty) continue;
    if (b is NoteTable && b.columns < 2) {
      b = NoteText(b.rows.map((r) => r.isEmpty ? '' : r.first).join('\n'));
    }
    final last = out.isEmpty ? null : out.last;
    if (b is NoteText && last is NoteText) {
      out[out.length - 1] = NoteText(last.text.isEmpty
          ? b.text
          : b.text.isEmpty
              ? last.text
              : '${last.text}\n${b.text}');
    } else if (b is NoteTable && last is! NoteText) {
      out
        ..add(const NoteText(''))
        ..add(b);
    } else {
      out.add(b);
    }
  }
  if (out.isEmpty || out.last is! NoteText) out.add(const NoteText(''));
  return out;
}

/// The stored form of [blocks]: the inverse of [parseNoteBlocks].
String serializeNoteBlocks(List<NoteBlock> blocks) {
  final parts = <String>[
    for (final b in blocks)
      switch (b) {
        NoteText(:final text) => text,
        NoteTable(:final rows) =>
          rows.map((r) => r.map(cleanCell).join('\t')).join('\n'),
      },
  ];
  // The empty text that only frames a table at either end adds nothing.
  while (parts.isNotEmpty && parts.first.isEmpty) {
    parts.removeAt(0);
  }
  while (parts.isNotEmpty && parts.last.isEmpty) {
    parts.removeLast();
  }
  return parts.join('\n');
}

/// What a paste of [blocks] inserts at the caret, or null when there is no
/// real table in it — the paste then goes ahead as ordinary text. The empty
/// text that frames a table is dropped; the caret's own text frames it.
List<NoteBlock>? pastedBlocks(List<NoteBlock> blocks) {
  final out = normalizeBlocks(blocks);
  if (!out.any((b) => b is NoteTable)) return null;
  if (out.first == const NoteText('')) out.removeAt(0);
  if (out.last == const NoteText('')) out.removeLast();
  return out;
}

/// Clipboard text holding a table: Excel and Sheets put tab-separated rows on
/// the clipboard, ending the last row with a newline.
List<NoteBlock>? pastedText(String text) =>
    text.contains('\t') ? pastedBlocks(parseNoteBlocks(text)) : null;

/// The trim the form applies before saving: whitespace around the note goes,
/// tabs stay. A note that opens with a table whose first cell is empty starts
/// with a tab, and stripping it would shift that row one column left.
String trimNote(String value) =>
    value.replaceAll(RegExp(r'^[^\S\t]+|[^\S\t]+$'), '');
