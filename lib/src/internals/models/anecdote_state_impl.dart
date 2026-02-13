import 'package:anecdotes/anecdotes.dart';

class AnecdoteStateImpl implements AnecdoteState {
  @override
  final String? captions;

  @override
  final Anecdote? anecdote;

  @override
  final int measureIndex;

  @override
  final AnecdoteStatus status;

  const AnecdoteStateImpl({
    this.measureIndex = 0,
    this.captions,
    this.anecdote,
    this.status = AnecdoteStatus.idle,
  });

  AnecdoteStateImpl copyWith({
    int? measureIndex,
    AnecdoteStatus? status,
    Anecdote? anecdote,
    String? captions,
  }) {
    return AnecdoteStateImpl(
      measureIndex: measureIndex ?? this.measureIndex,
      status: status ?? this.status,
      anecdote: anecdote ?? this.anecdote,
      captions: captions ?? this.captions,
    );
  }

  //TODO: equals
}
