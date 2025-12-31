import 'package:heart/heart.dart';
import 'package:maestro/maestro.dart';

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

enum MeasureCompletionType { voice, music, custom }

/// Base class representing a single measure or segment
/// within an [Anecdote].
///
/// A measure typically corresponds to one self-contained
/// part of a story, narration, or scene.
abstract class Measure {
  /// Unique identifier for this measure.
  int get id;

  /// Optional source file for the voice narration.
  AudioSource? get voiceSource;

  /// Optional source file for captions or subtitles.
  FileSource? get captionsSource;

  MeasureCompletionType get completionType;
}

/// Represents a complete anecdote composed of multiple [Measure]s.
///
/// An [Anecdote] defines the structure and assets for
/// a single story, lesson, or historical segment.
abstract class Anecdote {
  /// Ordered list of [Measure]s composing this anecdote.
  List<Measure> get measures;

  /// Optional source for the background music
  /// played throughout the anecdote.
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
