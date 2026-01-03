/// A library for displaying anecdotes in a beautiful and engaging way.
///
/// This library provides a simple way to display a series of anecdotes,
/// quotes, or short stories. It is designed to be easy to integrate into any
/// Flutter application.
///
/// It exports the main [AnecdoteWidget] for custom implementations, and
/// [AnecdoteCarousel] which is a pre-built carousel implementation.
library;

export 'package:maestro/maestro.dart'
    show
        AssetAudioSource,
        AudioPlayer,
        AudioSource,
        FilepathAudioSource,
        FutureBytesAudioSource,
        MusicPlayer,
        NetworkAudioSource,
        PlaylistSource;

export 'src/models/models.dart';
export 'src/widgets/anecdote_carousel.dart';
export 'src/widgets/anecdote_widget.dart';
