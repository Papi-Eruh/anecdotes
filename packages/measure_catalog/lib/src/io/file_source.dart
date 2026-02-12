import 'dart:typed_data';

/// Visitor interface for handling different types of [FileSource].
///
/// This follows the [Visitor design pattern]
/// (https://en.wikipedia.org/wiki/Visitor_pattern),
/// allowing specific behavior to be implemented for each kind of
/// [FileSource] without relying on type checks.
///
/// Example:
/// ```dart
/// class FileSourcePrinter implements FileSourceVisitor<void> {
///   @override
///   void visitAssetSource(AssetSource source) =>
///       print('Asset: ${source.path}');
///
///   @override
///   void visitFilepathSource(FilepathSource source) =>
///       print('File: ${source.path}');
///
///   @override
///   void visitNetworkSource(NetworkSource source) =>
///       print('Network: ${source.url}');
///
///   @override
///   void visitBytesSource(FutureBytesAudioSource source) =>
///       print('Future bytes source');
/// }
/// ```
abstract class FileSourceVisitor<T> {
  /// Called when visiting an [AssetSource].
  T visitAssetSource(AssetSource source);

  /// Called when visiting a [FilepathSource].
  T visitFilepathSource(FilepathSource source);

  /// Called when visiting a [NetworkSource].
  T visitNetworkSource(NetworkSource source);

  /// Called when visiting a [FutureBytesSource].
  T visitBytesSource(FutureBytesSource bytesAudioSource);
}

/// {@template file_source}
/// Abstract representation of a file source.
///
/// A [FileSource] represents any origin from which binary data can be
/// read, such as an asset, a local file, a network stream, or a
/// future-provided byte array.
///
/// This class uses the visitor pattern via the [accept] method to allow
/// for type-safe handling of different source types.
/// {@endtemplate}
abstract final class FileSource {
  /// {@macro file_source}
  const FileSource();

  /// Accepts a [visitor] to perform an operation based on the concrete
  /// type of the [FileSource].
  ///
  /// Returns the value produced by the visitor.
  T accept<T>(FileSourceVisitor<T> visitor);
}

/// {@template asset_source}
/// A [FileSource] representing a file bundled with the application.
///
/// This is typically used for assets declared in the `pubspec.yaml` file.
/// {@endtemplate}
final class AssetSource implements FileSource {
  /// {@macro asset_source}
  const AssetSource(this.path);

  /// The path to the asset within the application's asset bundle.
  final String path;

  @override
  T accept<T>(FileSourceVisitor<T> visitor) {
    return visitor.visitAssetSource(this);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetSource &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;
}

/// {@template filepath_source}
/// A [FileSource] representing a file on the local device's filesystem.
/// {@endtemplate}
final class FilepathSource implements FileSource {
  /// {@macro filepath_source}
  const FilepathSource(this.path);

  /// The absolute path to the file on the local filesystem.
  final String path;

  @override
  T accept<T>(FileSourceVisitor<T> visitor) {
    return visitor.visitFilepathSource(this);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilepathSource &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;
}

/// {@template network_source}
/// A [FileSource] representing a remote file accessible via a URL.
/// {@endtemplate}
final class NetworkSource implements FileSource {
  /// {@macro network_source}
  const NetworkSource(this.url);

  /// The URL pointing to the remote resource.
  final String url;

  @override
  T accept<T>(FileSourceVisitor<T> visitor) {
    return visitor.visitNetworkSource(this);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkSource &&
          runtimeType == other.runtimeType &&
          url == other.url;

  @override
  int get hashCode => url.hashCode;
}

/// {@template future_bytes_source}
/// A [FileSource] representing data that will be provided asynchronously.
///
/// This is useful for cases where the data must be loaded or generated
/// at runtime, such as decoding an audio buffer or downloading a file
/// into memory before playback.
/// {@endtemplate}
final class FutureBytesSource implements FileSource {
  /// {@macro future_bytes_source}
  const FutureBytesSource(this.bytesFuture);

  /// A [Future] that will resolve to the binary contents of the file.
  final Future<Uint8List> bytesFuture;

  @override
  T accept<T>(FileSourceVisitor<T> visitor) {
    return visitor.visitBytesSource(this);
  }
}
