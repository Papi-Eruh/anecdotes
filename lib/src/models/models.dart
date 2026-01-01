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

/// Base class representing a single measure or segment
/// within an [Anecdote].
///
/// A measure typically corresponds to one self-contained
/// part of a story, narration, or scene.
abstract class Measure {
  /// Optional source file for the voice narration.
  AudioSource? get voiceSource;

  /// Optional source file for captions or subtitles.
  FileSource? get captionsSource;

  /// Determines the strategy for finishing
  /// this measure and advancing to the next.
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
