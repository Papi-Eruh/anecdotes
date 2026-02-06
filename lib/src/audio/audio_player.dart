import 'package:anecdotes/src/audio/audio_source.dart';

abstract class AudioPlayer {
  Stream<Duration> get positionStream;

  Stream<Duration?> get durationStream;

  Future<void> load(AudioSource audioSource);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration duration);

  Future<void> next();
}
