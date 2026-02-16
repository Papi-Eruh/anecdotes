import 'package:anecdotes/src/anecdote_engine.dart';
import 'package:anecdotes/src/audio/audio_player.dart';
import 'package:anecdotes/src/internals/anecdote_engine_impl.dart';
import 'package:anecdotes/src/internals/captions_controller.dart';
import 'package:anecdotes/src/internals/measure_drawable_registry_impl.dart';
import 'package:anecdotes/src/measure_drawable_registry.dart';

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

MeasureDrawableRegistry<Drawable> createMeasureDrawableRegistry<Drawable>() {
  return MeasureDrawableRegistryImpl<Drawable>();
}
