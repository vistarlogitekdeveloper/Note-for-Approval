import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'note_blocks.dart';

/// Listens for pastes anywhere on the page. When the clipboard holds a table,
/// [onTablePaste] gets it as note blocks; if it takes it (returns true) the
/// browser's own paste is cancelled so the focused field doesn't also receive
/// the flattened text. Returns the callback that stops listening.
void Function() listenForTablePaste(
  bool Function(List<NoteBlock> blocks) onTablePaste,
) {
  final listener = ((web.ClipboardEvent e) {
    final data = e.clipboardData;
    if (data == null) return;
    final blocks = blocksFromHtml(data.getData('text/html')) ??
        pastedText(data.getData('text/plain'));
    if (blocks == null) return;
    if (onTablePaste(blocks)) e.preventDefault();
  }).toJS;
  // Capture phase: ahead of the text field that is about to insert it.
  web.window.addEventListener('paste', listener, true.toJS);
  return () => web.window.removeEventListener('paste', listener, true.toJS);
}

/// The clipboard's HTML as prose and tables, or null when it has no table.
List<NoteBlock>? blocksFromHtml(String html) {
  if (!html.toLowerCase().contains('<table')) return null;
  final body = web.DOMParser()
      .parseFromString(html.toJS, 'text/html')
      .body;
  if (body == null) return null;

  final blocks = <NoteBlock>[];
  final prose = StringBuffer();
  void flush() {
    blocks.add(NoteText(_tidy(prose.toString())));
    prose.clear();
  }

  void walk(web.Node node) {
    if (node.nodeType == web.Node.TEXT_NODE) {
      prose.write(_spaces(node.textContent ?? ''));
      return;
    }
    if (node.nodeType != web.Node.ELEMENT_NODE) return;
    final el = node as web.Element;
    final tag = el.tagName.toLowerCase();
    if (_skipped.contains(tag) || _hidden(el)) return;
    if (tag == 'table') {
      flush();
      blocks.add(NoteTable(_rows(el)));
      return;
    }
    if (tag == 'br') {
      prose.write('\n');
      return;
    }
    final isBlock = _blockTags.contains(tag);
    if (isBlock) prose.write('\n');
    for (var c = el.firstChild; c != null; c = c.nextSibling) {
      walk(c);
    }
    if (isBlock) prose.write('\n');
  }

  walk(body);
  flush();
  return pastedBlocks(blocks);
}

List<List<String>> _rows(web.Element table) {
  final rows = <List<String>>[];
  final trs = table.querySelectorAll('tr');
  for (var i = 0; i < trs.length; i++) {
    final tr = trs.item(i)! as web.Element;
    if (_hidden(tr)) continue;
    final row = <String>[];
    for (var c = tr.firstElementChild; c != null; c = c.nextElementSibling) {
      final tag = c.tagName.toLowerCase();
      if ((tag != 'td' && tag != 'th') || _hidden(c)) continue;
      row.add(cleanCell(_spaces(_cellText(c))));
      final span = int.tryParse(c.getAttribute('colspan') ?? '') ?? 1;
      for (var s = 1; s < span; s++) {
        row.add('');
      }
    }
    if (row.isNotEmpty) rows.add(row);
  }
  return rows;
}

/// A cell's text, with a line break inside it read as a space.
String _cellText(web.Node node) {
  if (node.nodeType == web.Node.TEXT_NODE) return node.textContent ?? '';
  if (node.nodeType != web.Node.ELEMENT_NODE) return '';
  final el = node as web.Element;
  final tag = el.tagName.toLowerCase();
  if (tag == 'br') return ' ';
  if (_skipped.contains(tag) || _hidden(el)) return '';
  final out = StringBuffer();
  for (var c = el.firstChild; c != null; c = c.nextSibling) {
    out.write(_cellText(c));
    if (_blockTags.contains(tag)) out.write(' ');
  }
  return out.toString();
}

const _skipped = {'head', 'style', 'script', 'title', 'meta', 'link', 'template'};

const _blockTags = {
  'p', 'div', 'li', 'ul', 'ol', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
  'blockquote', 'pre', 'section', 'article', 'header', 'footer', 'hr',
};

bool _hidden(web.Element el) => (el.getAttribute('style') ?? '')
    .toLowerCase()
    .replaceAll(' ', '')
    .contains('display:none');

/// HTML whitespace: any run is one space. Excel writes `&nbsp;` for spaces it
/// wants kept, which still reads as a space here.
String _spaces(String s) => s.replaceAll(RegExp(r'[\s ]+'), ' ');

/// Prose collected around the tables: trimmed lines, no stacks of blank ones.
String _tidy(String s) => s
    .split('\n')
    .map((l) => l.trim())
    .join('\n')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();
