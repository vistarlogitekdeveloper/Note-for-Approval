import 'package:intl/intl.dart';

final _dateFmt = DateFormat('dd MMM yyyy');
final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');
final _timeFmt = DateFormat('hh:mm a');

String formatDate(DateTime? dt) => dt == null ? '—' : _dateFmt.format(dt.toLocal());
String formatDateTime(DateTime? dt) => dt == null ? '—' : _dateTimeFmt.format(dt.toLocal());
String formatTime(DateTime? dt) => dt == null ? '—' : _timeFmt.format(dt.toLocal());

/// Returns e.g. "2 hours ago", "just now"
String timeAgo(DateTime? dt) {
  if (dt == null) return '—';
  final diff = DateTime.now().difference(dt.toLocal());
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return _dateFmt.format(dt.toLocal());
}

/// Truncates long text with ellipsis
String truncate(String text, int maxLength) =>
    text.length <= maxLength ? text : '${text.substring(0, maxLength)}…';

/// Returns e.g. "4.2 MB". Uses the 1024-based units browsers and the upload
/// limit are expressed in, so a file the server rejects at 20 MB does not read
/// as 19.1 MB here.
String formatBytes(int? bytes) {
  if (bytes == null) return '—';
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var size = bytes / 1024;
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[unit]}';
}

/// Returns "A" "AB" initials from a full name
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}
