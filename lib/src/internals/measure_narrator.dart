import 'dart:async';

abstract interface class MeasureNarrator {
  Stream<void> get onCompletedStream;
  void start();

  void play();

  void pause();

  void dispose();
}
