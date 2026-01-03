import 'package:anecdotes/src/models/models.dart';

/// A [FileSourceVisitor] for web platforms that currently does not support
/// file content reading.
///
/// This implementation throws an [UnsupportedError] for all visit methods,
/// as reading from assets, file paths, or byte streams is not supported
/// in this web-specific context.
class FileContentVisitor implements FileSourceVisitor<Future<String>> {
  /// Throws an [UnsupportedError] because assets are not supported on web.
  @override
  Future<String> visitAssetSource(AssetSource source) {
    throw UnsupportedError('Assets are not supported on web.');
  }

  /// Throws an [UnsupportedError] because byte streams are not supported on web.
  @override
  Future<String> visitBytesSource(FutureBytesSource bytesAudioSource) {
    throw UnsupportedError('Bytes are not supported on web.');
  }

  /// Throws an [UnsupportedError] because file paths are not supported on web.
  @override
  Future<String> visitFilepathSource(FilepathSource source) {
    throw UnsupportedError('Filepaths are not supported on web.');
  }

  /// Throws an [UnsupportedError] because network requests are not supported
  /// in this context on web.
  @override
  Future<String> visitNetworkSource(NetworkSource source) {
    throw UnsupportedError('Network are not supported on web.');
  }
}
