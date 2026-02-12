import 'package:anecdotes/src/models/anecdote.dart';
import 'package:anecdotes/src/models/anecdote_state.dart';

abstract interface class AnecdoteEngine {
  Stream<AnecdoteState> get stateStream;

  Future<void> load(
    Anecdote anecdote, {
    int startIndex = 0,
    AnecdoteStatus initialStatus = AnecdoteStatus.ready,
  });

  void play();

  void pause();

  void jumpTo(int measureIndex);

  void next();

  void previous();

  void dispose();
}
