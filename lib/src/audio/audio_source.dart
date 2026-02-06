import 'dart:typed_data';

import 'package:anecdotes/src/audio/audio_source_visitor.dart';

/// Abstract representation of an audio source.
abstract final class AudioSource {
  /// Accepts a visitor to handle the audio source based on its type.
  T accept<T>(AudioSourceVisitor<T> visitor);
}

/// Audio source from an asset included in the project.
final class AssetAudioSource implements AudioSource {
  const AssetAudioSource(this.path);

  /// Path to the asset.
  final String path;

  @override
  T accept<T>(AudioSourceVisitor<T> visitor) {
    return visitor.visitAssetSource(this);
  }
}

/// Audio source from a local file path.
final class FilepathAudioSource implements AudioSource {
  const FilepathAudioSource(this.path);

  /// Path to the local file.
  final String path;

  @override
  T accept<T>(AudioSourceVisitor<T> visitor) {
    return visitor.visitFilepathSource(this);
  }
}

/// Audio source from a network URL.
final class NetworkAudioSource implements AudioSource {
  const NetworkAudioSource(this.url);

  /// URL of the audio file.
  final String url;

  @override
  T accept<T>(AudioSourceVisitor<T> visitor) {
    return visitor.visitNetworkSource(this);
  }
}

/// Playlist composed of multiple [AudioSource]s.
final class PlaylistSource implements AudioSource {
  const PlaylistSource(this.list);

  /// List of audio sources in the playlist.
  final List<AudioSource> list;

  @override
  T accept<T>(AudioSourceVisitor<T> visitor) {
    return visitor.visitPlaylistSource(this);
  }
}

/// Audio source from bytes provided asynchronously.
final class FutureBytesAudioSource implements AudioSource {
  const FutureBytesAudioSource(this.bytesFuture);

  /// Future returning the audio bytes.
  final Future<Uint8List> bytesFuture;

  @override
  T accept<T>(AudioSourceVisitor<T> visitor) {
    return visitor.visitBytesSource(this);
  }
}

final class SilenceAudioSource implements AudioSource {
  const SilenceAudioSource();

  @override
  T accept<T>(AudioSourceVisitor<T> visitor) {
    return visitor.visitSilenceSource(this);
  }
}
