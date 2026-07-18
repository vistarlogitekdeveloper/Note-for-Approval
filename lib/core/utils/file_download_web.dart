import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Browser download: wrap the bytes in a Blob, point a hidden anchor at it,
/// and click it.
///
/// [mimeType] matters — with the wrong type the browser can rename the file or
/// try to display it inline instead of saving it.
Future<void> downloadBytes(
  Uint8List bytes,
  String fileName, {
  String? mimeType,
}) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType ?? 'application/octet-stream'),
  );

  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    // Never rendered; it only needs to exist long enough to be clicked.
    ..style.display = 'none';

  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();

  // The object URL pins the blob in memory until it is revoked. Revoking
  // immediately can race the download in some browsers, so give it a beat.
  await Future<void>.delayed(const Duration(seconds: 1));
  web.URL.revokeObjectURL(url);
}
