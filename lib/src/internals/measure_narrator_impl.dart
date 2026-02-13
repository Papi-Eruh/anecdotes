import 'dart:async';

import 'package:anecdotes/anecdotes.dart';
import 'package:anecdotes/src/internals/captions_controller.dart';
import 'package:anecdotes/src/internals/measure_narrator.dart';
import 'package:rxdart/rxdart.dart';

class MeasureNarratorImpl implements MeasureNarrator {
  final CaptionsController? _captionsController;
  final AudioPlayer? _voicePlayer;
  final AudioPlayer? _musicPlayer;
  final Measure measure;

  final _completedController = StreamController<void>.broadcast();
  StreamSubscription? _voiceSubscription;
  StreamSubscription? _musicSubscription;

  MeasureNarratorImpl({
    required this.measure,
    CaptionsController? captionsController,
    AudioPlayer? voicePlayer,
    AudioPlayer? musicPlayer,
  }) : _captionsController = captionsController,
       _voicePlayer = voicePlayer,
       _musicPlayer = musicPlayer;

  @override
  Stream<void> get onCompletedStream => _completedController.stream;

  @override
  void start() {
    final captionList = measure.captionList;
    if (captionList.isNotEmpty) {
      if (_captionsController == null) throw Exception('Should not be null');
      _captionsController.start(captionList);
    }

    final completionType = measure.completionType;
    if (completionType == MeasureCompletionType.voice) {
      if (_voicePlayer == null) throw Exception();
      _voiceSubscription = _voicePlayer.onTrackEnded().listen((_) {
        _completedController.add(null);
      });
    }
    if (completionType == MeasureCompletionType.music) {
      if (_musicPlayer == null) throw Exception();
      _voiceSubscription = _musicPlayer.onTrackEnded().listen((_) {
        _completedController.add(null);
      });
    }
  }

  @override
  void play() {
    _captionsController?.play();
    _musicPlayer?.play();
    _voicePlayer?.play();
  }

  @override
  void pause() {
    _captionsController?.pause();
    _musicPlayer?.pause();
    _voicePlayer?.pause();
  }

  @override
  void dispose() {
    _captionsController?.stop();
    if (!_completedController.isClosed) _completedController.close();
    _voiceSubscription?.cancel();
    _musicSubscription?.cancel();
  }
}

extension AudioPlayerSyncX on AudioPlayer {
  Stream<void> onTrackEnded() {
    return durationStream.pairwise().where(
      (pair) => pair[0] != null && pair[1] == null,
    );
  }
}
