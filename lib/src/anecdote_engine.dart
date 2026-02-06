import 'package:anecdotes/src/models/anecdote.dart';
import 'package:anecdotes/src/models/anecdote_state.dart';

/// The primary interface for controlling the playback and lifecycle of an anecdote.
///
/// This acts as the "brain" of the operation, abstracting state management,
/// sequencing, and resource preloading away from the UI layer.
/// It replaces the previous `AnecdoteWidgetController` and `_AnecdoteWidgetState` logic.
abstract interface class AnecdoteEngine {
  /// A stream of state changes suitable for UI rebuilding.
  Stream<AnecdoteState> get stateStream;

  //needed for play pause etc...
  /// The current synchronous state of the engine.
  AnecdoteState get currentState;

  /// Loads a new anecdote and initializes the engine.
  ///
  /// This method triggers the preloading process for the starting measure (at [startIndex])
  /// and potentially the subsequent measure to ensure smooth playback.
  Future<void> load(Anecdote anecdote, {int startIndex = 0});

  /// Starts or resumes playback.
  void play();

  /// Pauses playback (Music, Voice-over, and Captions).
  void pause();

  Future<void> jumpTo(int index);

  /// Advances to the next measure.
  ///
  /// This method handles:
  /// 1. Stopping the current [MeasureRunner].
  /// 2. Starting the next [MeasureRunner] (which should ideally be pre-loaded).
  /// 3. Triggering the pre-loading (buffering) of the measure at `index + 2`.
  Future<void> next();

  /// Returns to the previous measure.
  Future<void> previous();

  /// Releases all resources (Audio players, Streams, Subscriptions).
  /// This should be called when the anecdote widget is removed from the tree.
  void dispose();
}
