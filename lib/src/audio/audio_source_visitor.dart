import 'package:anecdotes/src/audio/audio_source.dart';

/// Visitor interface used to handle each specific type of [AudioSource].
///
/// This interface follows the visitor design pattern,
/// allowing operations to be performed on different [AudioSource] subtypes
/// without knowing their concrete implementation.
abstract class AudioSourceVisitor<T> {
  /// Called when visiting an [AssetAudioSource].
  T visitAssetSource(AssetAudioSource source);

  /// Called when visiting a [FilepathAudioSource].
  T visitFilepathSource(FilepathAudioSource source);

  /// Called when visiting a [NetworkAudioSource].
  T visitNetworkSource(NetworkAudioSource source);

  /// Called when visiting a [PlaylistSource].
  T visitPlaylistSource(PlaylistSource source);

  /// Called when visiting a [FutureBytesAudioSource].
  T visitBytesSource(FutureBytesAudioSource bytesAudioSource);

  /// Called when visiting a [SilenceAudioSource].
  T visitSilenceSource(SilenceAudioSource silenceAudioSource);
}
