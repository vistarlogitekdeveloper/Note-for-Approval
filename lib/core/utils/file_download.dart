/// Saves bytes the user asked for to a file they can actually find.
///
/// The PDF and attachment endpoints both require the Bearer token, so neither
/// can be a plain `<a href>` — the bytes come back through Dio and have to be
/// handed to the browser (or platform) here.
///
/// Web gets a real download with the correct MIME type; other platforms fall
/// back to the share sheet, which is the closest equivalent they have.
library;

export 'file_download_io.dart'
    if (dart.library.js_interop) 'file_download_web.dart';
