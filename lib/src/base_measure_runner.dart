import 'dart:async';

import 'package:anecdotes/anecdotes.dart';
import 'package:rxdart/rxdart.dart';

abstract class BaseMeasureRunner implements MeasureRunner {
  final Measure _measure;
  final CaptionsController? _captionsController;
  final AudioPlayer? _voicePlayer;
  final AudioPlayer? _musicPlayer;

  final _completedController = StreamController<void>.broadcast();
  StreamSubscription? _voiceSubscription;
  StreamSubscription? _musicSubscription;

  BaseMeasureRunner({
    required Measure measure,
    CaptionsController? captionsController,
    AudioPlayer? voicePlayer,
    AudioPlayer? musicPlayer,
  }) : _measure = measure,
       _captionsController = captionsController,
       _voicePlayer = voicePlayer,
       _musicPlayer = musicPlayer;

  @override
  Stream<void> get onCompleted => _completedController.stream;

  @override
  Future<void> prepare() async {
    await onPrepare();
  }

  @override
  void start() {
    final captionList = _measure.captionList;
    if (captionList.isNotEmpty) {
      if (_captionsController == null) throw Exception('Should not be null');
      _captionsController.start(captionList);
    }
    complete().then(_onComplete);
  }

  @override
  void play() {
    _captionsController?.play();
    _voicePlayer?.play();
    onPlay();
  }

  @override
  void pause() {
    _captionsController?.pause();
    _voicePlayer?.pause();
    onPause();
  }

  @override
  void stop() {
    _captionsController?.stop();
    onStop();
    if (!_completedController.isClosed) _completedController.close();
    _voiceSubscription?.cancel();
    _musicSubscription?.cancel();
  }

  FutureOr<void> _onComplete(_) {
    if (!_completedController.isClosed) _completedController.add(null);
  }

  Future<void> complete() async {
    final completer = Completer<void>();
    final completionType = _measure.completionType;

    switch (completionType) {
      case MeasureCompletionType.voice:
        if (_voicePlayer == null) throw Exception('should not be null');
        _voiceSubscription = _voicePlayer.onTrackEnded().listen(
          (_) => completer.complete(),
        );
        break;
      case MeasureCompletionType.music:
        if (_musicPlayer == null) throw Exception('should not be null');
        _musicSubscription = _musicPlayer.onTrackEnded().listen(
          (_) => completer.complete(),
        );
        break;
      case MeasureCompletionType.custom:
        completer.complete(completeCustom());
        break;
    }
    return completer.future;
  }

  Future<void> completeCustom() async {
    throw UnimplementedError(
      'With measure.completionType == MeasureCompletionType.custom, you should override this method.',
    );
  }

  Future<void> onPrepare();
  void onPlay();
  void onPause();
  void onStop();
}

extension AudioPlayerSyncX on AudioPlayer {
  Stream<void> onTrackEnded() {
    return durationStream.pairwise().where(
      (pair) => pair[0] != null && pair[1] == null,
    );
  }
}
