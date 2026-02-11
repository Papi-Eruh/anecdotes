import 'package:anecdotes/anecdotes.dart';

class AnecdoteContext {
  final AudioPlayer? voicePlayer;
  final AudioPlayer? musicPlayer;
  final CaptionsController? captionsController;

  AnecdoteContext({
    this.voicePlayer,
    this.musicPlayer,
    this.captionsController,
  });
}
