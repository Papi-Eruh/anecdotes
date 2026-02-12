import 'package:anecdotes/src/anecdote_engine.dart';
import 'package:anecdotes/src/audio/audio_player.dart';
import 'package:anecdotes/src/internals/anecdote_engine_impl.dart';
import 'package:anecdotes/src/internals/captions_controller.dart';

AnecdoteEngine createEngine({
  AudioPlayer? musicPlayer,
  AudioPlayer? voicePlayer,
  CaptionsController? captionsController,
}) {
  return AnecdoteEngineImpl(
    musicPlayer: musicPlayer,
    voicePlayer: voicePlayer,
    captionsController: captionsController,
  );
}
