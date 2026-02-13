import 'package:anecdotes/src/models/anecdote_state.dart';

class EngineState {
  /// The status applied only when the first measure of the anecdote
  /// becomes ready.
  ///
  /// This determines if the anecdote starts playing automatically
  /// or stays in a ready state on the first screen.
  final AnecdoteStatus startStatus;

  /// starting index measure
  final int startIndex;

  final bool isLooping;

  final Set<int> readyMeasureIndexSet;

  const EngineState({
    this.startStatus = AnecdoteStatus.ready,
    this.isLooping = false,
    this.readyMeasureIndexSet = const {},
    this.startIndex = 0,
  });

  EngineState copyWith({
    AnecdoteStatus? startStatus,
    Set<int>? readyMeasureIndexSet,
  }) {
    return EngineState(
      startStatus: startStatus ?? this.startStatus,
      readyMeasureIndexSet: readyMeasureIndexSet ?? this.readyMeasureIndexSet,
    );
  }

  bool isMeasureReady(int index) {
    return readyMeasureIndexSet.contains(index);
  }
}
