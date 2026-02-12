import 'dart:async';

import 'package:anecdotes/anecdotes.dart';
import 'package:anecdotes/src/internals/captions_controller.dart';
import 'package:anecdotes/src/internals/measure_narrator.dart';
import 'package:anecdotes/src/internals/measure_narrator_impl.dart';
import 'package:rxdart/rxdart.dart';

class AnecdoteEngineImpl implements AnecdoteEngine {
  final AudioPlayer? _musicPlayer;
  final AudioPlayer? _voicePlayer;
  final CaptionsController? _captionsController;

  final BehaviorSubject<AnecdoteState> _stateSubject;
  final Map<int, MeasureNarrator> _narratorByMeasureIndex = {};

  StreamSubscription<void>? _currentMeasureSubscription;

  AnecdoteEngineImpl({
    AudioPlayer? musicPlayer,
    AudioPlayer? voicePlayer,
    CaptionsController? captionsController,
  }) : _musicPlayer = musicPlayer,
       _voicePlayer = voicePlayer,
       _captionsController = captionsController,
       _stateSubject = BehaviorSubject.seeded(
         const AnecdoteState(index: 0, status: AnecdoteStatus.idle),
       );

  AnecdoteState get _currentState => _stateSubject.value;

  @override
  Stream<AnecdoteState> get stateStream => _stateSubject.stream;

  @override
  Future<void> load(
    Anecdote anecdote, {
    int startIndex = 0,
    AnecdoteStatus initialStatus = AnecdoteStatus.ready,
  }) async {
    assert(
      initialStatus == AnecdoteStatus.ready ||
          initialStatus == AnecdoteStatus.playing,
      'todo',
    );
    _disposeAnecdote();
    _emitState(
      status: AnecdoteStatus.loading,
      index: startIndex,
      anecdote: anecdote,
    );

    await Future.wait([_loadMusic(anecdote), _loadVoices(anecdote)]);
    _jumpTo(startIndex, initialStatus: initialStatus);
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

  @override
  void play() {
    final state = _currentState;
    if (state.currentMeasure == null) return;
    final runner = _narratorByMeasureIndex[state.index];
    if (runner != null) {
      _musicPlayer?.play();
      runner.play();
      _emitState(status: AnecdoteStatus.playing);
    }
  }

  @override
  void pause() {
    final index = _currentState.index;
    _musicPlayer?.pause();
    _narratorByMeasureIndex[index]?.pause();
    _emitState(status: AnecdoteStatus.paused);
  }

  @override
  void dispose() {
    _disposeAnecdote();
    _stateSubject.close();
  }

  void _disposeAnecdote() {
    _currentMeasureSubscription?.cancel();
    _musicPlayer?.pause();
    _voicePlayer?.pause();
    _captionsController?.stop();
    for (final runner in _narratorByMeasureIndex.values) {
      runner.dispose();
    }
    _narratorByMeasureIndex.clear();
  }

  @override
  void next() {
    final anecdote = _currentState.anecdote;
    if (anecdote == null) return;

    final nextIndex = _currentState.index + 1;
    final totalMeasures = anecdote.measures.length;

    if (nextIndex >= totalMeasures) {
      if (_currentState.isLooping) {
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
    final prevIndex = _currentState.index - 1;
    if (prevIndex >= 0) {
      _jumpTo(prevIndex);
    }
  }

  @override
  void jumpTo(int measureIndex) async {
    if (measureIndex < 0 || measureIndex >= _currentState.measureCount) {
      throw StateError('');
    }
    _jumpTo(measureIndex);
  }

  /// [initialStatus] != null means it's an initial loading.
  void _jumpTo(int index, {AnecdoteStatus? initialStatus}) async {
    await _currentMeasureSubscription?.cancel();
    _currentMeasureSubscription = null;

    final previousIndex = _currentState.index;

    if (initialStatus == null && previousIndex != index) {
      _narratorByMeasureIndex[previousIndex]?.dispose();
    }

    MeasureNarrator? narrator;

    if (!_narratorByMeasureIndex.containsKey(index)) {
      narrator = _getOrLoadNarrator(index);
    } else {
      narrator = _narratorByMeasureIndex[index];
    }

    if (narrator == null) return; //TODO: throw
    _currentMeasureSubscription = narrator.onCompletedStream.listen((_) {
      next();
    });

    _emitState(status: initialStatus ?? AnecdoteStatus.playing, index: index);

    if (initialStatus != AnecdoteStatus.ready) {
      narrator.start();
      _musicPlayer?.play();
    }

    _performSlidingWindowMaintenance(index);
  }

  MeasureNarrator? _getOrLoadNarrator(int index) {
    final anecdote = _currentState.anecdote;
    if (anecdote == null) throw StateError('');
    if (index < 0 || index >= _currentState.measureCount) return null;
    final activeRunner = _narratorByMeasureIndex[index];
    if (activeRunner != null) return activeRunner;
    return _loadNarrator(index);
  }

  MeasureNarrator _loadNarrator(int index) {
    final measure = _currentState.anecdote!.measures[index];
    final narrator = MeasureNarratorImpl(
      measure: measure,
      captionsController: _captionsController,
      voicePlayer: _voicePlayer,
      musicPlayer: _musicPlayer,
    );
    return _narratorByMeasureIndex[index] = narrator;
  }

  void _performSlidingWindowMaintenance(int currentIndex) {
    _getOrLoadNarrator(currentIndex + 1);
    _narratorByMeasureIndex.removeWhere((key, narrator) {
      final shouldKeep = key >= currentIndex - 1 && key <= currentIndex + 1;
      if (!shouldKeep) {
        narrator.dispose();
        return true;
      }
      return false;
    });
  }

  void _emitState({
    required AnecdoteStatus status,
    int? index,
    bool? isLooping,
    Anecdote? anecdote,
  }) {
    if (_stateSubject.isClosed) return;
    _stateSubject.add(
      _currentState.copyWith(
        status: status,
        index: index,
        isLooping: isLooping,
        anecdote: anecdote,
      ),
    );
  }
}
