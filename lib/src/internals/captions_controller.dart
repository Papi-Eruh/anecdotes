import 'package:anecdotes/anecdotes.dart';

/// Controls the synchronization and playback of captions for a specific measure.
abstract interface class CaptionsController {
  /// A stream that emits the current text to display based on timing.
  /// Emits `null` when no text should be shown (silence).
  Stream<String?> get textStream;

  /// Initializes the controller with data and subscribes to the audio position.
  /// Should be called during the `prepare()` phase of the MeasureRunner.
  void start(List<Caption> captions);

  /// Resumes caption synchronization (e.g. after a pause).
  void play();

  /// Pauses the synchronization of captions.
  void pause();

  /// Stops synchronization, cancels subscriptions, and resets the state.
  void stop();

  /// Cleans up resources.
  void dispose();
}
