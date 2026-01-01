# Anecdotes

> This package was born out of the development of the [Erudit](https://github.com/Papi-Eruh/erudit_public) application. We decided to make it open source so other developers can benefit from it.

![Anecdotes](./resources/images/anecdotes.webp)

## What is Anecdotes ?

Anecdotes is a Flutter package that provides widgets for telling stories (or **anecdotes**) with images, animations, music, lyrics, subtitles, etc.

### Built with

* [![Flutter][Flutter]][Flutter-url]
* [![Dart][Dart]][Dart-url]

## Getting started

### Prerequisites

Make sure you have the Flutter SDK (version >=3.35.0) and Dart SDK (version >=3.9.0) installed.

### Installation

To use this package, add it as a git dependency in your `pubspec.yaml` file. 
```yaml
dependencies:
  flutter:
    sdk: flutter
  anecdotes:
    git:
      url: https://github.com/Papi-Eruh/anecdotes.git
```

Then, run `flutter pub get` in your project's root directory.

## Usage

This package provides two primary widgets for building your stories: `AnecdoteWidget` and `AnecdoteCarousel`.

-   `AnecdoteWidget`: The core widget that plays a single story, or **anecdote**.
-   `AnecdoteCarousel`: A `PageView` that displays multiple `AnecdoteWidget`s in sequence.

An anecdote is composed of one or more **Measures**. A `Measure` is an abstract class representing a single scene in your story. `Anecdote` is also an abstract class that holds the list of measures.

To render your measures, you must provide `AnecdoteWidget` with a `MeasureBuilderRegistry`. This registry maps each of your `Measure` types to the widget that knows how to render it.

You can find pre-built measures and their corresponding widgets in the companion [anecdotes_catalog](https://github.com/Papi-Eruh/anecdotes_catalog) package, or create your own.

### Music, Voices, and Completion

`AnecdoteWidget` can orchestrate background music and voice-overs that are synchronized with your measures.

**Audio**

-   **Music**: To play background music for the entire anecdote, pass a `musicPlayer` to the `AnecdoteWidget`. The anecdote itself should contain an `AudioSource` in its `musicSource` property.
-   **Voices**: For audio that is specific to a single scene (like a voice-over), you can add an `AudioSource` to the `voiceSource` property of a `Measure`.

This package does not handle audio playback directly. We recommend using a player package like [maestro_just_audio](https://github.com/Papi-Eruh/maestro_just_audio), which is designed to work seamlessly with `anecdotes`.

Here is a conceptual example:
```dart
// 1. Define your anecdote with a music source
class MyStory implements Anecdote {
  @override
  final musicSource = PlaylistSource([
    AssetAudioSource('assets/audio/intro_music.mp3'),
    AssetAudioSource('assets/audio/main_theme.mp3'),
  ]);

  @override
  List<Measure> get measures => [
    // A measure with its own voice-over
    MyMeasure(
      voiceSource: AssetAudioSource('assets/audio/voice_over_1.mp3'),
    ),
    MyMeasure(),
  ];
}

// 2. Create a music player (e.g., with maestro_just_audio)
final maestro = createMaestro();

// 3. Pass the player to the widget
AnecdoteWidget(
  anecdote: MyStory(),
  musicPlayer: maestro.musicPlayer,
  measureBuilderRegistry: registry,
)
```

### Captions

`AnecdoteWidget` can display subtitles synchronized with audio. To enable this, provide a `captionsSource` on a `Measure`.

To render the captions, you need to provide a `captionBuilder` to the `AnecdoteWidget`. This builder receives the current caption and allows you to define how it should be displayed.

Here is a minimal example of a `captionBuilder`:
```dart
AnecdoteWidget(
  // ... other properties
  captionBuilder: (context, caption) {
    if (caption == null) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: Text(caption.text),
    );
  },
)
```

To parse a caption file, you must provide a `CaptionsAdapter` to the `AnecdoteWidget`. For example, the package provides `JsonCaptionsAdapter` for handling JSON-based caption files. You can create your own implementation to support other formats like SRT or VTT.

**Managing Measure Completion**

Each measure needs to signal when it is complete so that the `AnecdoteWidget` can advance to the next one. There are two ways to manage this:

1.  **Declarative Completion**: Set the `completionType` property on your `Measure`. For example, `MeasureCompletionType.music` will automatically complete the measure when the corresponding audio track in your playlist finishes.

    ```dart
    // This measure will complete when its corresponding music track ends.
    const WorldMapMeasure(
      countryCode: 'FR',
      completionType: MeasureCompletionType.music,
    )
    ```

2.  **Programmatic Completion**: For more complex logic, you can override the `resolveCompletion()` method in your `MeasureBaseState`. This method should return a `Future` that completes when your measure's work is done (e.g., an animation has finished).

    ```dart
    class MyCustomMeasureState extends MeasureBaseState<MyCustomMeasureWidget>
        with SingleTickerProviderStateMixin {
      final _completer = Completer<void>();
      late final AnimationController _myAnimationController;

      @override
      void initState() {
        super.initState();
        _myAnimationController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
        _myAnimationController.addStatusListener(_onAnimationStatusChanged);
      }

      void _onAnimationStatusChanged(AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          if (!_completer.isCompleted) {
            _completer.complete();
          }
        }
      }

      @override
      void dispose() {
        _myAnimationController.removeStatusListener(_onAnimationStatusChanged);
        _myAnimationController.dispose();
        super.dispose();
      }

      @override
      void onPlay() {
        _myAnimationController.forward();
      }

      @override
      Future<void> resolveCompletion() {
        return _completer.future;
      }

      // ... other methods and build()
    }
    ```
    A more detailed example is available in the "Creating a Custom Measure" section below.

### Example Scenario

Let's create an anecdote with two scenes that are synchronized with music:

1.  **Scene 1**: Display a looping Rive animation of pirates.
2.  **Scene 2**: Show a map focused on Jamaica.

We'll use `LoopingRiveMeasure` and `WorldMapMeasure` from the `anecdotes_catalog` package, and a music player from `maestro_just_audio`.

For a more complete and functional example, you can check out the example in the `anecdotes_catalog` repository: [anecdotes_catalog/example/lib/main.dart](https://github.com/Papi-Eruh/anecdotes_catalog/blob/main/example/lib/main.dart).

Here’s how you could implement this:

```dart
import 'package:anecdotes/anecdotes.dart';
import 'package:anecdotes_catalog/anecdotes_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:maestro_just_audio/maestro_just_audio.dart';

void main() {
  // Make sure to add dependencies to your pubspec.yaml
  // dependencies:
  //   ...
  //   flutter_svg: ^2.0.9 # use latest version
  //   maestro_just_audio:
  //     git:
  //       url: https://github.com/Papi-Eruh/maestro_just_audio.git
  //
  // And declare your assets:
  // flutter:
  //   assets:
  //     - assets/animations/pirates.riv
  //     - assets/audio/barco_aventura.mp3
  //     - assets/flags/jm.svg # from anecdotes_catalog, or your own flag widgets
  runApp(const MyApp());
}

class MyAnecdote implements Anecdote {
  const MyAnecdote({required this.measures, this.musicSource});

  @override
  final List<Measure> measures;
  @override
  final AudioSource? musicSource;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _registry = MeasureBuilderRegistry();
  final _maestro = createMaestro();

  @override
  void initState() {
    _registry
      ..register<LoopingRiveMeasure>(
        (context, measure) => LoopingRiveMeasureWidget(measure: measure),
      )
      ..register<WorldMapMeasure>(
        (context, measure) => WorldMapMeasureWidget(
          measure: measure,
          languageCode: 'en',
          countryWidgetBuilder: (cc, path) => SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SvgPicture.asset(path, height: 100),
            ),
          ),
        ),
      );
    super.initState();
  }

  @override
  void dispose() {
    _maestro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AnecdoteWidget(
        musicPlayer: _maestro.musicPlayer,
        anecdote: MyAnecdote(
          measures: [
            LoopingRiveMeasure(
              riveSource: AssetSource('assets/animations/pirates.riv'),
              completionType: MeasureCompletionType.music,
            ),
            WorldMapMeasure(
              countryCode: 'JM',
              completionType: MeasureCompletionType.music,
            ),
          ],
          musicSource: PlaylistSource([
            AssetAudioSource('assets/audio/barco_aventura.mp3'),
            AssetAudioSource('assets/audio/barco_aventura.mp3'),
          ]),
        ),
        measureBuilderRegistry: _registry,
      ),
    );
  }
}
```

### Creating a Custom Measure

Creating a custom measure involves a few more steps, as you need to manage the state and lifecycle of the measure's widget.

1.  **`Measure` implementation**: An interface holding the data for your scene.
2.  **`MeasureBaseWidget`**: A `StatefulWidget` that will render the measure.
3.  **`MeasureBaseState`**: The logic for your widget, where you control animations and signal completion.

Let's create a `FadeInTextMeasure` that displays text with a fade-in animation.

**1. Define the `Measure` Implementation**

This class implements `Measure` and holds the data needed for the scene.

```dart
class FadeInTextMeasure implements Measure {
  const FadeInTextMeasure({
    required this.id,
    required this.text,
    required this.msDuration,
    this.captionsSource,
    this.voiceSource,
  });

  @override
  final int id;
  @override
  final FileSource? captionsSource;
  @override
  final AudioSource? voiceSource;

  final String text;
  final int msDuration;
}
```

**2. Create the `MeasureBaseWidget` and its `State`**

The widget is stateful. The `State` class handles the animation and tells the `AnecdoteWidget` when the measure is complete.

```dart
class FadeInTextMeasureWidget extends MeasureBaseWidget<FadeInTextMeasure> {
  const FadeInTextMeasureWidget({super.key, required super.measure});

  @override
  MeasureBaseState<FadeInTextMeasureWidget> createState() =>
      _FadeInTextMeasureWidgetState();
}

class _FadeInTextMeasureWidgetState extends MeasureBaseState<FadeInTextMeasureWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _completer = Completer<void>();

  FadeInTextMeasure get measure => widget.measure;

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (!_completer.isCompleted) {
        _completer.complete();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  void onPlay() {
    _controller.forward();
  }

  @override
  void onPause() {
    _controller.stop();
  }

  @override
  Future<void> prepareBeforeReady() async {
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: measure.msDuration));
    _controller.addStatusListener(_onAnimationStatusChanged);
  }

  @override
  Future<void> resolveCompletion() {
    return _completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Center(
        child: Text(measure.text),
      ),
    );
  }
}
```

**3. Register Your New Widget**

Just like with the catalog widgets, you need to register your custom measure so `AnecdoteWidget` can build it.

```dart
// Add this to your MeasureBuilderRegistry setup
registry.register<FadeInTextMeasure>(
  (context, measure) => FadeInTextMeasureWidget(
    measure: measure,
  ),
);
```
Now you can use `FadeInTextMeasure` in your `Anecdote`'s list of measures.

## Contributing

### Top contributors:

## License

Distributed under the MIT License. See `./LICENSE` for more information.

## Contact

<contact@erudit.app>  
Project link: <https://erudit.app>

## Acknowledgments

* https://github.com/othneildrew/Best-README-Template
* https://cli.vgv.dev/


[Dart]: https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white
[Dart-url]: https://dart.dev/
[Flutter]: https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white
[Flutter-url]: https://flutter.dev/
