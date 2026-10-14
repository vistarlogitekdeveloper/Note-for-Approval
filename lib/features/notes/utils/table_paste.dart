/// Hooks the browser's paste so a table copied from Excel, Teams, Word or
/// Google Sheets arrives in a note as a table instead of a heap of loose lines.
///
/// A Flutter text field only ever sees the clipboard's plain text, and the
/// plain text of a table is unreliable — Excel gives tab-separated rows, Teams
/// and Word often give one cell per line. The HTML flavour always has the real
/// `<table>`, so on the web the paste event is read before the field gets it.
///
/// Other platforms get no hook; the editor still recognises Excel's
/// tab-separated text once it lands in the field.
library;

export 'table_paste_stub.dart'
    if (dart.library.js_interop) 'table_paste_web.dart';
