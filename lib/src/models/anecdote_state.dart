import 'package:anecdotes/anecdotes.dart';

/// Represents the possible global playback states of the anecdote engine.
enum AnecdoteStatus {
  /// The engine is idle; no anecdote is loaded or active.
  idle,

  /// The engine is currently loading resources.
  /// This occurs during initial setup or critical buffering when the next measure is not ready.
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

/// Represents a complete, immutable snapshot of the [AnecdoteEngine]'s state.
class AnecdoteState {
  /// The index of the currently active measure within the anecdote.
  final int index;

  /// The current operational status (playing, paused, loading, etc.).
  final AnecdoteStatus status;

  /// The active anecdote data. Is null if no anecdote is loaded.
  final Anecdote? anecdote;

  /// Whether the engine is configured to loop back to index 0 upon completion.
  final bool isLooping;

  //TODO: add isPlaying

  const AnecdoteState({
    required this.index,
    required this.status,
    this.anecdote,
    this.isLooping = false,
  });

  /// Returns the specific [Measure] associated with the current [index].
  /// Returns null if no anecdote is loaded or if the index is out of bounds.
  Measure? get currentMeasure {
    final measures = anecdote?.measures;
    if (measures == null || index < 0 || index >= measures.length) return null;
    return measures[index];
  }

  bool get isPlaying => status == AnecdoteStatus.playing;
  bool get isPaused => status == AnecdoteStatus.paused;

  int get measureCount {
    return anecdote?.measures.length ?? 0;
  }

  AnecdoteState copyWith({
    int? index,
    AnecdoteStatus? status,
    Anecdote? anecdote,
    bool? isLooping,
  }) {
    return AnecdoteState(
      index: index ?? this.index,
      status: status ?? this.status,
      anecdote: anecdote ?? this.anecdote,
      isLooping: isLooping ?? this.isLooping,
    );
  }
}
