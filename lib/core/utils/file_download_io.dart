import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Non-web fallback. There is no "downloads folder" convention shared across
/// mobile and desktop, so hand the bytes to the platform share sheet and let
/// the user choose where they go.
///
/// `sharePdf` is named for its usual payload but takes arbitrary bytes and
/// preserves the filename, so it serves attachments too. [mimeType] is
/// accepted for signature parity with the web implementation; the platform
/// infers the type from the extension here.
Future<void> downloadBytes(
  Uint8List bytes,
  String fileName, {
  String? mimeType,
}) async {
  await Printing.sharePdf(bytes: bytes, filename: fileName);
}
