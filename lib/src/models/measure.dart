import 'package:anecdotes/src/audio/audio_source.dart';
import 'package:anecdotes/src/models/caption.dart';

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

  AudioSource? get musicSource;

  /// Optional source file for the voice narration.
  ///
  /// This [AudioSource] is played when the measure becomes active.
  AudioSource? get voiceSource;

  /// Optional source file for captions or subtitles.
  ///
  /// The content of this file is expected to be in a format that can be
  /// parsed into a list of [Caption].
  List<Caption> get captionList;

  /// Determines the strategy for finishing this measure and advancing to the
  /// next.
  ///
  /// See [MeasureCompletionType] for available strategies.
  MeasureCompletionType get completionType;
}
