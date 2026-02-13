import 'package:anecdotes/anecdotes.dart';

/// Represents the possible global playback states of the anecdote engine.
enum AnecdoteStatus {
  /// The engine is idle; no anecdote is loaded or active.
  idle,

  /// The engine is performing global setup (loading the playlist,
  /// pre-fetching the first few audio files, etc.).
  /// Use this for "Global Splash/Loading" UI.
  initializing,

  /// The engine is loading a specific measure.
  loading,

  /// The anecdote is ready to be played.
  ready,

  /// The anecdote is actively playing.
  playing,

  /// Playback has been suspended by the user or a system event.
  paused,

  /// The anecdote has reached its end.
  finished,
}

abstract class AnecdoteState {
  AnecdoteStatus get status;
  Anecdote? get anecdote;

  /// Current measure index
  int get measureIndex;
  String? get captions;
}
