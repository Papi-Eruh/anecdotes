import 'package:anecdotes/src/audio/audio_source.dart';
import 'package:anecdotes/src/models/measure.dart';

/// {@template anecdote}
/// Represents a complete anecdote composed of multiple [Measure]s.
///
/// An [Anecdote] defines the structure and assets for a single story, lesson,
/// or historical segment. It contains the list of measures that make up the
/// narrative and an optional background music track.
/// {@endtemplate}
abstract class Anecdote {
  /// {@macro anecdote}
  const Anecdote();

  /// The ordered list of [Measure]s that compose this anecdote.
  List<Measure> get measures;

  /// An optional [AudioSource] for the background music to be played
  /// throughout the anecdote.
  AudioSource? get musicSource;
}
