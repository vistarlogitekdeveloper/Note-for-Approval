import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../utils/note_blocks.dart';
import '../utils/table_paste.dart';

/// The Brief Note box. Reads and writes [controller] as plain text like any
/// other field, but a table pasted from Excel, Teams or Word shows up as a real
/// table (each cell still editable) instead of one cell per line. See
/// note_blocks.dart for how a table is kept inside the text.
class BriefNoteField extends StatefulWidget {
  const BriefNoteField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.maxChars,
    this.enabled = true,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxChars;
  final bool enabled;
  final String? Function(String?)? validator;

  @override
  State<BriefNoteField> createState() => _BriefNoteFieldState();
}

/// One run of the note in the editor: prose, or a table.
sealed class _Seg {
  void dispose();
}

class _TextSeg extends _Seg {
  _TextSeg(String text) : ctrl = TextEditingController(text: text);
  final TextEditingController ctrl;
  final focus = FocusNode();

  @override
  void dispose() {
    ctrl.dispose();
    focus.dispose();
  }
}

class _TableSeg extends _Seg {
  _TableSeg(NoteTable t)
      : cells = [
          for (final r in t.rows) [for (final c in r) TextEditingController(text: c)],
        ],
        focus = [
          for (final r in t.rows) [for (final _ in r) FocusNode()],
        ];
  final List<List<TextEditingController>> cells;
  final List<List<FocusNode>> focus;

  NoteTable get table => NoteTable([
        for (final r in cells) [for (final c in r) c.text],
      ]);

  @override
  void dispose() {
    for (final c in cells.expand((r) => r)) {
      c.dispose();
    }
    for (final f in focus.expand((r) => r)) {
      f.dispose();
    }
  }
}

class _BriefNoteFieldState extends State<BriefNoteField> {
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  List<_Seg> _segs = [];

  /// The value last written to, or read from, the controller — so our own
  /// writes are not mistaken for an outside change and re-parsed.
  String _synced = '';
  late final void Function() _stopPaste;

  @override
  void initState() {
    super.initState();
    _synced = widget.controller.text;
    _load(parseNoteBlocks(_synced));
    widget.controller.addListener(_onOutsideChange);
    _stopPaste = listenForTablePaste(_onTablePaste);
  }

  @override
  void dispose() {
    _stopPaste();
    widget.controller.removeListener(_onOutsideChange);
    for (final s in _segs) {
      s.dispose();
    }
    super.dispose();
  }

  // ── Model ──────────────────────────────────────────────────────────────────

  List<NoteBlock> get _blocks => [
        for (final s in _segs)
          switch (s) {
            _TextSeg() => NoteText(s.ctrl.text),
            _TableSeg() => s.table,
          },
      ];

  /// Rebuild the segments from [blocks], then put the caret in segment
  /// [focusAt]: at [offset] in a text run, or in [cell] (row, column) of a
  /// table.
  void _load(
    List<NoteBlock> blocks, {
    int? focusAt,
    int offset = 0,
    (int, int)? cell,
  }) {
    final old = _segs;
    _segs = [
      for (final b in normalizeBlocks(blocks))
        switch (b) {
          NoteText(:final text) => _TextSeg(text),
          NoteTable() => _TableSeg(b),
        },
    ];
    for (final s in _segs) {
      switch (s) {
        case _TextSeg():
          s.ctrl.addListener(() => _onTextEdited(s));
          s.focus.addListener(_onFocus);
        case _TableSeg():
          for (final c in s.cells.expand((r) => r)) {
            c.addListener(_push);
          }
          for (final f in s.focus.expand((r) => r)) {
            f.addListener(_onFocus);
          }
      }
    }
    // The old fields are still mounted until the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final s in old) {
        s.dispose();
      }
      if (!mounted) return;
      final target = focusAt == null ? null : _segs.elementAtOrNull(focusAt);
      if (target is _TextSeg) {
        target.focus.requestFocus();
        target.ctrl.selection = TextSelection.collapsed(
          offset: offset.clamp(0, target.ctrl.text.length),
        );
      } else if (target is _TableSeg && cell != null) {
        target.focus[cell.$1][cell.$2].requestFocus();
      }
    });
  }

  /// Write the editor's content back to the controller.
  void _push() {
    final value = serializeNoteBlocks(_blocks);
    if (value == _synced) return;
    _synced = value;
    widget.controller.text = value;
    _fieldKey.currentState?.didChange(value);
  }

  void _onOutsideChange() {
    final value = widget.controller.text;
    if (value == _synced) return;
    _synced = value;
    setState(() => _load(parseNoteBlocks(value)));
    _fieldKey.currentState?.didChange(value);
  }

  void _onFocus() => setState(() {});

  bool get _hasFocus => _segs.any((s) => switch (s) {
        _TextSeg() => s.focus.hasFocus,
        _TableSeg() => s.focus.expand((r) => r).any((f) => f.hasFocus),
      });

  /// Tab-separated text reached a text run without passing through the paste
  /// hook (a phone's paste, or a browser clipboard with no HTML). It is still
  /// Excel's table format, so turn it into a table where it landed.
  void _onTextEdited(_TextSeg seg) {
    if (!seg.ctrl.text.contains('\t')) return _push();
    final i = _segs.indexOf(seg);
    final pasted = parseNoteBlocks(seg.ctrl.text);
    final blocks = _blocks..replaceRange(i, i + 1, pasted);
    final tablesBefore = _segs.take(i).whereType<_TableSeg>().length;
    final tablesIn = pasted.whereType<NoteTable>().length;
    setState(() => _load(blocks, focusAt: 2 * (tablesBefore + tablesIn)));
    _push();
  }

  // ── Paste ──────────────────────────────────────────────────────────────────

  /// A table was pasted somewhere on the page. Take it if the caret is in this
  /// field; otherwise leave the paste to whoever has focus.
  bool _onTablePaste(List<NoteBlock> pasted) {
    if (!widget.enabled) return false;
    for (var i = 0; i < _segs.length; i++) {
      final s = _segs[i];
      switch (s) {
        case _TextSeg() when s.focus.hasFocus:
          _insertAt(i, s.ctrl.selection, pasted);
          return true;
        case _TableSeg():
          for (var r = 0; r < s.focus.length; r++) {
            for (var c = 0; c < s.focus[r].length; c++) {
              if (!s.focus[r][c].hasFocus) continue;
              final only = pasted.whereType<NoteTable>().toList();
              if (pasted.length == 1 && only.length == 1) {
                _fillFrom(i, r, c, only.single);
              } else {
                // Prose and tables mixed: put it all just under this table.
                _insertAt(i + 1, const TextSelection.collapsed(offset: 0), pasted);
              }
              return true;
            }
          }
        default:
      }
    }
    return false;
  }

  /// Split text run [i] at [sel] and put [pasted] in between.
  void _insertAt(int i, TextSelection sel, List<NoteBlock> pasted) {
    final text = (_segs[i] as _TextSeg).ctrl.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    // The stored form puts each table on its own lines, so the line break the
    // caret sat next to is already implied.
    var before = text.substring(0, start);
    var after = text.substring(end);
    if (before.endsWith('\n')) before = before.substring(0, before.length - 1);
    if (after.startsWith('\n')) after = after.substring(1);

    final blocks = _blocks
      ..replaceRange(i, i + 1, [NoteText(before), ...pasted, NoteText(after)]);
    final tablesBefore = _segs.take(i).whereType<_TableSeg>().length;
    final tablesIn = pasted.whereType<NoteTable>().length;
    // The caret goes to the end of what was pasted.
    final tail = pasted.last;
    setState(() => _load(
          blocks,
          focusAt: 2 * (tablesBefore + tablesIn),
          offset: tail is NoteText ? (before.isEmpty ? 0 : before.length + 1) + tail.text.length : 0,
        ));
    _push();
  }

  /// Paste a table over table [i] starting at cell (r, c), the way a
  /// spreadsheet does — growing the table if the paste runs past its edge.
  void _fillFrom(int i, int r, int c, NoteTable pasted) {
    final rows = [
      for (final row in (_segs[i] as _TableSeg).table.rows) [...row],
    ];
    for (var pr = 0; pr < pasted.rows.length; pr++) {
      while (rows.length <= r + pr) {
        rows.add(List.filled(rows.first.length, '', growable: true));
      }
      for (var pc = 0; pc < pasted.columns; pc++) {
        final row = rows[r + pr];
        while (row.length <= c + pc) {
          row.add('');
        }
        row[c + pc] = pasted.rows[pr][pc];
      }
    }
    final blocks = _blocks..[i] = NoteTable(rows);
    setState(() => _load(blocks, focusAt: i, cell: (r, c)));
    _push();
  }

  void _removeTable(int i) {
    final blocks = _blocks..removeAt(i);
    setState(() => _load(blocks, focusAt: i - 1, offset: (_segs[i - 1] as _TextSeg).ctrl.text.length));
    _push();
  }

  // ── View ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: _fieldKey,
      initialValue: widget.controller.text,
      validator: (_) => widget.validator?.call(_synced),
      builder: (state) {
        final chars = _synced.length;
        final hasTable = _segs.any((s) => s is _TableSeg);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GestureDetector(
              // A click in the padding around the text still lands in the note.
              onTap: !widget.enabled || _hasFocus
                  ? null
                  : () => (_segs.last as _TextSeg).focus.requestFocus(),
              child: InputDecorator(
                isFocused: _hasFocus,
                isEmpty: _synced.isEmpty,
                decoration: InputDecoration(
                  labelText: widget.label,
                  alignLabelWithHint: true,
                  enabled: widget.enabled,
                  errorText: state.errorText,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _segs.length; i++)
                      switch (_segs[i]) {
                        final _TextSeg s => _textRun(s, single: !hasTable),
                        final _TableSeg s => _NoteTableEditor(
                            key: ObjectKey(s),
                            seg: s,
                            enabled: widget.enabled,
                            onRemove: () => _removeTable(i),
                          ),
                      },
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$chars / ${widget.maxChars}',
              style: TextStyle(
                color: chars > widget.maxChars ? context.c.bad : context.c.txt3,
                fontSize: 11.5,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Prose. With tables in the note, the runs around them start one line
  /// tall — the empty line after a table is where typing continues.
  Widget _textRun(_TextSeg s, {required bool single}) {
    return TextField(
      key: ObjectKey(s),
      controller: s.ctrl,
      focusNode: s.focus,
      enabled: widget.enabled,
      style: TextStyle(color: context.c.txt, fontSize: 14),
      // null maxLines is what makes the box grow instead of scroll.
      minLines: single ? 3 : 1,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      decoration: _bare.copyWith(
        hintText: single && _hasFocus ? widget.hint : null,
        hintStyle: TextStyle(color: context.c.txt3, fontSize: 13.5),
      ),
    );
  }
}

/// No box of its own: the runs and cells sit inside the field's one outline,
/// so every border the app theme would add is switched off.
const _bare = InputDecoration(
  isCollapsed: true,
  filled: false,
  contentPadding: EdgeInsets.zero,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
);

/// A pasted table inside the note: a bordered grid of editable cells, with
/// its size and a way to take it out again.
class _NoteTableEditor extends StatelessWidget {
  const _NoteTableEditor({
    super.key,
    required this.seg,
    required this.enabled,
    required this.onRemove,
  });

  final _TableSeg seg;
  final bool enabled;
  final VoidCallback onRemove;

  static final _noBreaks = FilteringTextInputFormatter.deny(
    RegExp(r'[\t\r\n]'),
    replacementString: ' ',
  );

  /// Wide enough for the longest cell in each column, within reason.
  List<double> _widths(BuildContext context, TextStyle cellStyle) {
    // Measured in the font the cell's TextField will actually use.
    final theme = Theme.of(context);
    final base = theme.useMaterial3 ? theme.textTheme.bodyLarge : theme.textTheme.titleMedium;
    final style = base?.merge(cellStyle) ?? cellStyle;
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    final cols = seg.cells.first.length;
    final widths = [
      for (var c = 0; c < cols; c++)
        seg.cells.fold<double>(0, (w, r) {
          painter
            ..text = TextSpan(text: r[c].text, style: style)
            ..layout();
          return painter.width > w ? painter.width : w;
        }),
    ];
    painter.dispose();
    // Cell padding plus room for the caret.
    return [for (final w in widths) (w + _cellPad.horizontal + 6).clamp(64, 360).toDouble()];
  }

  static const _cellPad = EdgeInsets.symmetric(horizontal: 8, vertical: 6);

  @override
  Widget build(BuildContext context) {
    final rows = seg.cells.length;
    final cols = seg.cells.first.length;
    final cellStyle = TextStyle(color: context.c.txt, fontSize: 13.5);
    final widths = _widths(context, cellStyle);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.table_chart_outlined, size: 15, color: context.c.txt3),
              const SizedBox(width: 6),
              Text(
                'Table · $rows ${rows == 1 ? 'row' : 'rows'} × $cols columns',
                style: TextStyle(color: context.c.txt3, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (enabled)
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Remove table'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.c.txt3,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(80),
              columnWidths: {
                for (var c = 0; c < cols; c++) c: FixedColumnWidth(widths[c]),
              },
              border: TableBorder.all(color: context.c.line2, width: 1),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                for (var r = 0; r < rows; r++)
                  TableRow(children: [
                    for (var c = 0; c < cols; c++)
                      Padding(
                        padding: _cellPad,
                        child: TextField(
                          controller: seg.cells[r][c],
                          focusNode: seg.focus[r][c],
                          enabled: enabled,
                          maxLines: 1,
                          inputFormatters: [_noBreaks],
                          style: cellStyle,
                          decoration: _bare,
                        ),
                      ),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
