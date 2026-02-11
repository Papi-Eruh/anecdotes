import 'dart:async';

/// Manages the lifecycle and logic of a single `Measure`.
///
/// This interface strictly separates the asset loading phase ([prepare]) from
/// the execution phase ([start]), allowing the engine to buffer future measures
/// while the current one is playing.
abstract interface class MeasureRunner {
  /// Loads necessary assets (Voice-over, JSON Captions, Images, etc.).
  ///
  /// The Engine calls this method on the "Next" measure while the "Current"
  /// measure is still playing to prevent loading gaps.
  Future<void> prepare();

  void start();

  /// Resumes the internal logic of this measure.
  void play();

  /// Pauses the internal logic of this measure.
  void pause();

  /// Stops execution and cleans up lightweight resources associated with this run.
  void stop();

  /// A stream that emits an event when the measure considers itself finished.
  ///
  /// This could be triggered by the end of a voice-over, a timer expiration,
  /// or a specific user interaction, signaling the Engine to auto-advance.
  Stream<void> get onCompleted;
}
