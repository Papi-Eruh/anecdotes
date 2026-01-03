import 'dart:typed_data';

import 'package:maestro/maestro.dart';
import 'package:meta/meta.dart';

/// Defines how background music should behave.
enum AncMusicBehavior {
  /// Push a new track to the player stack,
  /// allowing multiple layers of music to coexist.
  push,

  /// Replace the currently playing track with a new one.
  replace,

  /// Pushes a track to the player, and automatically
  /// pops it when the associated widget is disposed.
  scoped;

  /// Whether this behavior pushes a new track to the player.
  bool get isPushed => {push, scoped}.contains(this);

  /// Whether this behavior is scoped (automatically cleaned up).
  bool get isScoped => this == scoped;
}

/// Defines the strategy used to determine
/// when a [Measure] is considered "finished".
///
/// This dictates the automatic navigation to the next measure.
enum MeasureCompletionType {
  /// The measure finishes automatically
  /// when the [Measure.voiceSource] audio playback completes.
  ///
  /// This is the standard behavior for a narrated story.
  voice,

  /// The measure finishes automatically when the specific music segment
  /// defined for this measure completes.
  ///
  /// Useful for measures that are synchronized
  /// strictly with a musical structure.
  music,

  /// The measure finishes based on custom logic defined in the widget.
  ///
  /// If you select this type, you **must** override `resolveCompletionCustom()`
  /// in your `MeasureBaseState` implementation to manually trigger the end
  /// of the measure
  /// (e.g., after a user interaction, a video ending, or a timer).
  custom,
}

/// {@template measure}
/// Base class representing a single measure or segment within an [Anecdote].
///
/// A measure typically corresponds to one self-contained part of a story,
/// narration, or scene. It holds the sources for voice narration, captions,
/// and defines how its completion is determined.
/// {@endtemplate}
abstract class Measure {
  /// {@macro measure}
  const Measure();

  /// Optional source file for the voice narration.
  ///
  /// This [AudioSource] is played when the measure becomes active.
  AudioSource? get voiceSource;

  /// Optional source file for captions or subtitles.
  ///
  /// The content of this file is expected to be in a format that can be
  /// parsed into a list of [Captions].
  FileSource? get captionsSource;

  /// Determines the strategy for finishing this measure and advancing to the
  /// next.
  ///
  /// See [MeasureCompletionType] for available strategies.
  MeasureCompletionType get completionType;
}

/// {@template anecdote}
/// Represents a complete anecdote composed of multiple [Measure]s.
///
/// An [Anecdote] defines the structure and assets for a single story, lesson,
/// or historical segment. It contains the list of measures that make up the
/// narrative and an optional background music track.
/// {@endtemplate}
abstract class Anecdote {
  /// {@macro anecdote}
  const Anecdote();

  /// The ordered list of [Measure]s that compose this anecdote.
  List<Measure> get measures;

  /// An optional [AudioSource] for the background music to be played
  /// throughout the anecdote.
  AudioSource? get musicSource;
}

/// Represents the playback state of an [Anecdote].
///
/// Used to control and synchronize playback between multiple components.
enum AncState {
  /// The anecdote hasn't been played yet.
  init,

  /// The anecdote is currently playing.
  playing,

  /// The anecdote is currently paused.
  paused,

  /// The anecdote has finished playing.
  finished;

  /// Whether the state is [paused].
  bool get isPaused => this == AncState.paused;

  /// Whether the state is [playing].
  bool get isPlaying => this == AncState.playing;

  /// Whether the state is [finished].
  bool get isFinished => this == AncState.finished;

  /// Whether the anecdote is currently displayed to the user.
  bool get isVisible {
    return {AncState.playing, AncState.paused}.contains(this);
  }

  /// Returns the logical next state in a toggle sequence.
  AncState get next {
    switch (this) {
      case AncState.playing:
        return AncState.paused;
      case AncState.paused:
        return AncState.playing;
      case AncState.finished:
        return AncState.finished;
      case AncState.init:
        return AncState.playing;
    }
  }
}

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
@immutable
abstract final class FileSource {
  /// Creates a [FileSource] from a bundled asset path.
  factory FileSource.asset(String path) => AssetSource(path);

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

@immutable
class Captions {
  const Captions({
    required this.text,
    required this.startTime,
    required this.endTime,
  });

  /// 2. FromJson
  /// Note le mapping manuel des clés qui remplace @JsonKey
  factory Captions.fromJson(Map<String, dynamic> json) {
    return Captions(
      text: json['word'] as String,
      // Utilisation de 'num' pour accepter à la fois int et double venant du JSON
      startTime: (json['start_time'] as num).toDouble(),
      endTime: (json['end_time'] as num).toDouble(),
    );
  }
  final String text;
  final double startTime;
  final double endTime;

  /// Getter calculé (conservé tel quel)
  int get ms {
    return ((endTime - startTime) * 1000).toInt();
  }

  /// 1. CopyWith
  /// Permet de créer une copie modifiée de l'objet
  Captions copyWith({
    String? text,
    double? startTime,
    double? endTime,
  }) {
    return Captions(
      text: text ?? this.text,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  /// 3. ToJson
  Map<String, dynamic> toJson() {
    return {
      'word': text,
      'start_time': startTime,
      'end_time': endTime,
    };
  }

  /// 4. ToString (pour le debug)
  @override
  String toString() =>
      'Captions(text: $text, startTime: $startTime, endTime: $endTime)';

  /// 5. Égalité (Operator ==)
  /// Nécessaire pour comparer deux instances
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Captions &&
        other.text == text &&
        other.startTime == startTime &&
        other.endTime == endTime;
  }

  /// 6. HashCode
  /// Nécessaire si tu utilises ces objets dans un Set ou comme clé de Map
  @override
  int get hashCode => text.hashCode ^ startTime.hashCode ^ endTime.hashCode;
}
