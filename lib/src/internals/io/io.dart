/// Provides a platform-specific implementation of [FileContentVisitor].
///
/// This library uses conditional exports to select the appropriate
/// implementation at compile time:
/// - `file_content_visitor_io.dart` for platforms that support `dart:io`
///   (e.g., mobile, desktop).
/// - `file_content_visitor_web.dart` for web platforms that use `dart:html`.
/// - `file_content_visitor.dart` as a fallback.
library;

export 'file_content_visitor.dart'
    if (dart.library.io) 'file_content_visitor_io.dart'
    if (dart.library.html) 'file_content_visitor_web.dart';
