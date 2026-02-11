import 'dart:async';

import 'package:anecdotes/anecdotes.dart';
import 'package:rxdart/rxdart.dart';

class AnecdoteEngineImpl implements AnecdoteEngine {
  final MeasureRunnerFactory _runnerFactory;
  final AudioPlayer? _musicPlayer;
  final AudioPlayer? _voicePlayer;
  final CaptionsController? _captionsController;

  final BehaviorSubject<AnecdoteState> _stateSubject;
  final Map<int, MeasureRunner> _activeRunners = {};
  final Map<int, Future<MeasureRunner>> _loadingRunners = {};

  StreamSubscription<void>? _currentMeasureSubscription;

  AnecdoteEngineImpl({
    required MeasureRunnerFactory runnerFactory,
    AudioPlayer? musicPlayer,
    AudioPlayer? voicePlayer,
    CaptionsController? captionsController,
  }) : _runnerFactory = runnerFactory,
       _musicPlayer = musicPlayer,
       _voicePlayer = voicePlayer,
       _captionsController = captionsController,
       _stateSubject = BehaviorSubject.seeded(
         const AnecdoteState(index: 0, status: AnecdoteStatus.idle),
       );

  @override
  Stream<AnecdoteState> get stateStream => _stateSubject.stream;

  @override
  AnecdoteState get currentState => _stateSubject.value;

  @override
  Future<void> load(
    Anecdote anecdote, {
    int startIndex = 0,
    AnecdoteStatus status = AnecdoteStatus.ready,
  }) async {
    _cleanupAllRunners();
    _emitState(
      status: AnecdoteStatus.loading,
      index: startIndex,
      anecdote: anecdote,
    );

    await Future.wait([_loadMusic(anecdote), _loadVoices(anecdote)]);
    await _jumpTo(startIndex, initialStatus: status);
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
    final state = currentState;
    if (state.currentMeasure == null) return;
    final runner = _activeRunners[state.index];
    if (runner != null) {
      _musicPlayer?.play();
      runner.play();
      _emitState(status: AnecdoteStatus.playing);
    }
  }

  @override
  void pause() {
    final index = currentState.index;
    _musicPlayer?.pause();
    _activeRunners[index]?.pause();
    _emitState(status: AnecdoteStatus.paused);
  }

  @override
  void dispose() {
    _cleanupAllRunners();
    _stateSubject.close();
  }

  void _cleanupAllRunners() {
    _currentMeasureSubscription?.cancel();
    _musicPlayer?.pause();
    for (final runner in _activeRunners.values) {
      runner.stop();
    }
    _activeRunners.clear();
    _loadingRunners.clear();
  }

  @override
  Future<void> next() async {
    final anecdote = currentState.anecdote;
    if (anecdote == null) return;

    final nextIndex = currentState.index + 1;
    final totalMeasures = anecdote.measures.length;

    if (nextIndex >= totalMeasures) {
      if (currentState.isLooping) {
        await _jumpTo(0);
      } else {
        _emitState(status: AnecdoteStatus.finished);
        _musicPlayer?.pause();
      }
      return;
    }
    await _jumpTo(nextIndex);
  }

  @override
  Future<void> previous() async {
    final prevIndex = currentState.index - 1;
    if (prevIndex >= 0) {
      await _jumpTo(prevIndex);
    }
  }

  @override
  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= currentState.measureCount) throw StateError('');
    await _jumpTo(index);
  }

  /// [initialStatus] != null means it's an initial loading.
  Future<void> _jumpTo(int index, {AnecdoteStatus? initialStatus}) async {
    await _currentMeasureSubscription?.cancel();
    _currentMeasureSubscription = null;

    final previousIndex = currentState.index;

    if (initialStatus == null && previousIndex != index) {
      _activeRunners[previousIndex]?.stop();
    }

    MeasureRunner? runner;

    if (!_activeRunners.containsKey(index)) {
      _emitState(status: AnecdoteStatus.loading, index: index);
      runner = await _getOrLoadRunner(index);
    } else {
      runner = _activeRunners[index];
    }

    if (runner == null) return; //TODO: throw
    if (initialStatus != AnecdoteStatus.ready) {
      runner.start();
      _musicPlayer?.play();
    }
    _currentMeasureSubscription = runner.onCompleted.listen((_) {
      next();
    });

    _emitState(status: initialStatus ?? AnecdoteStatus.playing, index: index);
    _performSlidingWindowMaintenance(index);
  }

  Future<MeasureRunner?> _getOrLoadRunner(int index) async {
    final anecdote = currentState.anecdote;
    if (anecdote == null) throw StateError('');
    if (index < 0 || index >= currentState.measureCount) return null;
    final activeRunner = _activeRunners[index];
    if (activeRunner != null) return activeRunner;
    final pendingFuture = _loadingRunners[index];
    if (pendingFuture != null) return pendingFuture;
    final loadingFuture = _loadRunnerInternal(index);
    _loadingRunners[index] = loadingFuture;
    return loadingFuture;
  }

  Future<MeasureRunner> _loadRunnerInternal(int index) async {
    final context = AnecdoteContext(
      voicePlayer: _voicePlayer,
      musicPlayer: _musicPlayer,
      captionsController: _captionsController,
    );
    final measure = currentState.anecdote!.measures[index];
    final runner = _runnerFactory.createRunner(context, measure);
    try {
      await runner.prepare();
      _activeRunners[index] = runner;
      return runner;
    } catch (e) {
      rethrow;
    } finally {
      _loadingRunners.remove(index);
    }
  }

  void _performSlidingWindowMaintenance(int currentIndex) {
    unawaited(_getOrLoadRunner(currentIndex + 1));

    _activeRunners.removeWhere((key, runner) {
      final shouldKeep = key >= currentIndex - 1 && key <= currentIndex + 1;
      if (!shouldKeep) {
        runner.stop();
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
      currentState.copyWith(
        status: status,
        index: index,
        isLooping: isLooping,
        anecdote: anecdote,
      ),
    );
  }
}
