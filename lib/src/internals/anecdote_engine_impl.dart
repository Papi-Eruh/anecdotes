import 'dart:async';

import 'package:anecdotes/anecdotes.dart';
import 'package:anecdotes/src/internals/captions_controller.dart';
import 'package:anecdotes/src/internals/measure_narrator.dart';
import 'package:anecdotes/src/internals/measure_narrator_impl.dart';
import 'package:anecdotes/src/internals/models/anecdote_state_impl.dart';
import 'package:anecdotes/src/internals/models/engine_state.dart';
import 'package:rxdart/rxdart.dart';

class AnecdoteEngineImpl implements AnecdoteEngine {
  final AudioPlayer? _musicPlayer;
  final AudioPlayer? _voicePlayer;
  final CaptionsController? _captionsController;

  final BehaviorSubject<AnecdoteStateImpl> _anecdoteStateSubject;

  EngineState _engineState;
  MeasureNarrator? _currentNarator;
  StreamSubscription<void>? _onCompletedSubscription;

  AnecdoteEngineImpl({
    AudioPlayer? musicPlayer,
    AudioPlayer? voicePlayer,
    CaptionsController? captionsController,
  }) : _musicPlayer = musicPlayer,
       _voicePlayer = voicePlayer,
       _captionsController = captionsController,
       _anecdoteStateSubject = BehaviorSubject.seeded(
         const AnecdoteStateImpl(),
       ),
       _engineState = const EngineState();

  AnecdoteStateImpl get _anecdoteState => _anecdoteStateSubject.value;

  @override
  Stream<AnecdoteState> get stateStream => _anecdoteStateSubject.stream;

  @override
  Future<void> load(
    Anecdote anecdote, {
    int startIndex = 0,
    AnecdoteStatus startStatus = AnecdoteStatus.ready,
    bool isLooping = false,
  }) async {
    assert(
      startStatus == AnecdoteStatus.ready ||
          startStatus == AnecdoteStatus.playing,
      'todo',
    );
    _disposeAnecdote();
    _engineState = EngineState(
      startStatus: startStatus,
      isLooping: isLooping,
      startIndex: startIndex,
    );
    _emitState(
      status: AnecdoteStatus.loading,
      measureIndex: startIndex,
      anecdote: anecdote,
    );

    await Future.wait([_loadMusic(anecdote), _loadVoices(anecdote)]);
    _jumpTo(startIndex);
  }

  Future<void> _loadMusic(Anecdote anecdote) async {
    if (_musicPlayer == null) return;
    AudioSource? musicSource;
    final measureMusicSources = anecdote.measures.map((e) => e.musicSource);
    if (measureMusicSources.any((e) => e != null)) {
      final list = measureMusicSources.map((s) {
        if (s == null) return SilenceAudioSource();
        return s;
      }).toList();
      musicSource = PlaylistSource(list);
    }

    // Music from measure > from anecdote
    musicSource ??= anecdote.musicSource;
    if (musicSource != null) await _musicPlayer.load(musicSource);
  }

  Future<void> _loadVoices(Anecdote anecdote) async {
    if (_voicePlayer == null) return;
    AudioSource? voiceSource;
    final measureVoiceSources = anecdote.measures.map((e) => e.voiceSource);
    if (measureVoiceSources.every((s) => s == null)) return; //TODO: throw ?
    final list = measureVoiceSources.map((s) {
      if (s == null) return SilenceAudioSource();
      return s;
    }).toList();
    voiceSource = PlaylistSource(list);
    await _voicePlayer.load(voiceSource);
  }

  void _play([int? measureIndex]) {
    _emitState(status: AnecdoteStatus.playing, measureIndex: measureIndex);
    _currentNarator?.play();
  }

  @override
  void play() {
    final status = _anecdoteState.status;
    if (status == AnecdoteStatus.playing ||
        status == AnecdoteStatus.loading ||
        status == AnecdoteStatus.idle) {
      throw StateError('Cannot run play()');
    }
    _play();
  }

  @override
  void pause() {
    final status = _anecdoteState.status;
    if (status == AnecdoteStatus.paused ||
        status == AnecdoteStatus.loading ||
        status == AnecdoteStatus.idle) {
      throw StateError('Cannot run pause()');
    }
    _currentNarator?.pause();
    _emitState(status: AnecdoteStatus.paused);
  }

  @override
  void dispose() {
    _disposeAnecdote();
    _anecdoteStateSubject.close();
  }

  void _disposeAnecdote() {
    _onCompletedSubscription?.cancel();
    _musicPlayer?.pause();
    _voicePlayer?.pause();
    _captionsController?.stop();
    _currentNarator?.dispose();
  }

  @override
  void next() {
    final anecdote = _anecdoteState.anecdote;
    if (anecdote == null) return;

    final nextIndex = _anecdoteState.measureIndex + 1;
    final totalMeasures = anecdote.measures.length;

    if (nextIndex >= totalMeasures) {
      if (_engineState.isLooping) {
        _jumpTo(0);
      } else {
        _emitState(status: AnecdoteStatus.finished);
        _musicPlayer?.pause();
      }
      return;
    }
    _jumpTo(nextIndex);
  }

  @override
  void previous() async {
    final prevIndex = _anecdoteState.measureIndex - 1;
    if (prevIndex < 0) throw Exception('Cannot go previous');
    _jumpTo(prevIndex);
  }

  @override
  void jumpTo(int measureIndex) async {
    if (measureIndex < 0 ||
        measureIndex >= (_anecdoteState.anecdote?.measures.length ?? 0)) {
      throw StateError("Can't jump to an index not in [0:measures.length].");
    }
    _jumpTo(measureIndex);
  }

  /// [initialStatus] != null means it's an initial loading.
  Future<void> _jumpTo(int index) async {
    final previousIndex = _anecdoteState.measureIndex;
    if (index == previousIndex) {
      throw Exception('Cannot jump to the same measure.');
    }
    await _onCompletedSubscription?.cancel();
    _currentNarator?.dispose();

    _currentNarator = _loadNarrator(index);
    _onCompletedSubscription = _currentNarator?.onCompletedStream.listen(
      (_) => next(),
    );

    if (_engineState.isMeasureReady(index)) {
      _play(index);
    } else {
      _emitState(status: AnecdoteStatus.loading, measureIndex: index);
    }
  }

  MeasureNarrator _loadNarrator(int index) {
    final anecdote = _anecdoteState.anecdote;
    if (anecdote == null) {
      throw StateError("Can't load narrator without anecdote loaded.");
    }
    final measure = anecdote.measures[index];
    return MeasureNarratorImpl(
      measure: measure,
      captionsController: _captionsController,
      voicePlayer: _voicePlayer,
      musicPlayer: _musicPlayer,
    );
  }

  void _emitState({
    AnecdoteStatus? status,
    int? measureIndex,
    Anecdote? anecdote,
    String? captions,
  }) {
    if (_anecdoteStateSubject.isClosed) return;
    _anecdoteStateSubject.add(
      _anecdoteState.copyWith(
        status: status,
        measureIndex: measureIndex,
        anecdote: anecdote,
        captions: captions,
      ),
    );
  }

  @override
  void notifyReady(int measureIndex) {
    final readyIndexSet = {..._engineState.readyMeasureIndexSet, measureIndex};
    _engineState = _engineState.copyWith(readyMeasureIndexSet: readyIndexSet);
    if (measureIndex != _anecdoteState.measureIndex) return;

    if (_anecdoteState.status == AnecdoteStatus.initializing &&
        _engineState.startStatus == AnecdoteStatus.ready) {
      return _emitState(status: AnecdoteStatus.ready);
    }
    play();
  }
}
