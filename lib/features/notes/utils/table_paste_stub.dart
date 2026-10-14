import 'note_blocks.dart';

/// No paste event to hook outside the browser. Returns the "stop" callback.
void Function() listenForTablePaste(
  bool Function(List<NoteBlock> blocks) onTablePaste,
) =>
    () {};
