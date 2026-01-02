# Anecdotes

> This package was born out of the development of the [Erudit](https://github.com/Papi-Eruh/erudit_public) application. We decided to make it open source so other developers can benefit from it.

![Anecdotes](./resources/images/anecdotes.webp)

## What is Anecdotes ?

Anecdotes is a Flutter package that provides a powerful and flexible framework for telling stories (or **anecdotes**). It allows you to compose narratives from individual scenes, combining images, animations, music, and text to create rich, engaging experiences.

### Key Features:

*   **Story Composition**: Build stories (`Anecdote`) from a sequence of scenes (`Measure`), giving you a clear and organized structure for your narrative.
*   **Custom Scene Widgets**: You have complete freedom to create your own Flutter widgets for each scene. If you can build it in Flutter, you can make it a part of your anecdote.
*   **Animation and Lifecycle Control**: Manage the state of your scenes with `play`, `pause`, and completion callbacks. The framework gives you the hooks to control animations and other time-based events.
*   **Flexible Scene Duration**: Define how long each scene should last. You can tie the duration to the length of a voice-over, a piece of music, or implement custom logic for programmatic control.
*   **Extensible Builder Registry**: The `MeasureBuilderRegistry` lets you map your scene data models to their corresponding widgets, promoting a clean, decoupled architecture.
*   **Audio Orchestration**: Easily layer background music for an entire anecdote and add specific voice-overs to individual scenes. The package is designed to integrate with audio player packages like `maestro_just_audio`.
*   **Synchronized Captions**: Display subtitles synchronized with your audio. The package provides adapters for common caption formats and allows you to build your own.
*   **Carousel for Multiple Stories**: The `AnecdoteCarousel` widget makes it simple to display multiple anecdotes in a swipeable `PageView`.
*   **Pre-built Components**: For common use cases, the [anecdotes_catalog](https://github.com/Papi-Eruh/anecdotes_catalog) package provides ready-to-use measures and widgets, such as for Rive animations and world maps.

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

Welcome to the `anecdotes` package! Let's build an anecdote together, one step at a time.

> A complete, ready-to-test version of this example is available in the `/example` directory of this project.

### The Core Concepts: `Anecdote` and `Measure`

At its heart, an anecdote is simple. In this package:

-   An **`Anecdote`** is your story. It's a class that holds all the parts of your narrative.
-   A **`Measure`** is a single scene or step in your story. An `Anecdote` is composed of a list of `Measure`s.

Think of it like a movie: the `Anecdote` is the movie, and each `Measure` is a scene.

These are abstract classes. You'll create your own classes that implement them.

### Bringing a Story to Life with `AnecdoteWidget`

The `AnecdoteWidget` is the stage where your story is performed. It takes an `Anecdote` and renders it.

But how does it know *what* to show for each `Measure`? It needs a little help.

### Creating a Custom `Measure` Widget

To display a `Measure`, you need a corresponding widget. Let's create one that fades in a line of text. This is a great example of a custom animated scene.

#### Define the `Measure` Data

This class holds the data for our scene: the text to display and the duration of the fade animation.

```dart
import 'package:anecdotes/anecdotes.dart';

class FadeInTextMeasure implements Measure {
  const FadeInTextMeasure({
    required this.text,
    required this.msDuration,
    this.captionsSource,
    this.voiceSource,
    this.completionType = MeasureCompletionType.custom,
  });

  @override
  final FileSource? captionsSource;
  @override
  final AudioSource? voiceSource;
  @override
  final MeasureCompletionType completionType;

  final String text;
  final int msDuration;
}
```

#### Create the `Measure` Widget and its `State`

The `State` class must extend `MeasureBaseState`, which gives you methods to control the scene's lifecycle. Here, we'll use an `AnimationController` to drive the fade and a `Completer` to signal when the animation is finished.

First, let's define the widget and the basic state class. The state will hold an `AnimationController` to drive the fade, a `Completer` to signal when the animation is finished, and a variable to track the animation's progress. This progress tracking is necessary because an anecdote can be paused and resumed, and we need to know where to restart the animation from.

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:anecdotes/anecdotes.dart';

class FadeInTextMeasureWidget extends MeasureBaseWidget<FadeInTextMeasure> {
  const FadeInTextMeasureWidget({super.key, required super.measure});

  @override
  MeasureBaseState<FadeInTextMeasure, FadeInTextMeasureWidget> createState() =>
      _FadeInTextMeasureWidgetState();
}

class _FadeInTextMeasureWidgetState
    extends MeasureBaseState<FadeInTextMeasure, FadeInTextMeasureWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _completer = Completer<void>();
  double _animValue = 0;

  FadeInTextMeasure get measure => widget.measure;
}
```

Next, we'll set up the `AnimationController` in the `prepareBeforeReady` method. This method is called before the measure is displayed, making it the perfect place for initialization. We also add a status listener to the controller that will complete our `Completer` when the animation finishes.

```dart
// In _FadeInTextMeasureWidgetState

void _onAnimationStatusChanged(AnimationStatus status) {
  if (status == AnimationStatus.completed) {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}

@override
Future<void> prepareBeforeReady() async {
  _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: measure.msDuration),
  );
  _controller.addStatusListener(_onAnimationStatusChanged);
}
```

We need to clean up our controller when the widget is disposed to prevent memory leaks.

```dart
// In _FadeInTextMeasureWidgetState

@override
void dispose() {
  _controller.removeStatusListener(_onAnimationStatusChanged);
  _controller.dispose();
  super.dispose();
}
```

Now, let's implement the play and pause logic. `onPlay` will start the animation from where it left off, and `onPause` will stop it and save its current progress.

```dart
// In _FadeInTextMeasureWidgetState

@override
void onPlay() {
  _controller.forward(from: _animValue);
}

@override
void onPause() {
  _animValue = _controller.value;
  _controller.stop();
}
```

Now, we need to tell the `AnecdoteWidget` when this measure is complete so it can move to the next one. This is done via the `completionType` property on the `Measure`. There are two main approaches:

**Declarative Completion**: The easy way. You let an audio source determine the duration.
-   `MeasureCompletionType.voice`: The scene ends when the `voiceSource` finishes playing.
-   `MeasureCompletionType.music`: The scene ends when its corresponding track in the `musicSource` playlist finishes.

```dart
// This measure will end when its music track ends.
const WorldMapMeasure(
  countryCode: 'FR',
  completionType: MeasureCompletionType.music,
)
```

**Programmatic Completion**: The flexible way. You decide when the scene is over.
-   `MeasureCompletionType.custom`: You are in full control.
-   In your `MeasureBaseState`, you must override the `resolveCompletionCustom()` method.
-   This method should return a `Future` that completes whenever your scene's work is done.

Our `FadeInTextMeasure` uses `completionType = MeasureCompletionType.custom` by default. We'll use the `Completer` we created earlier to signal completion. The `future` of the `Completer` (which completes when our fade animation ends) is returned by `resolveCompletionCustom`.

```dart
// In _FadeInTextMeasureWidgetState

@override
Future<void> resolveCompletionCustom() {
  return _completer.future;
}
```

Finally, the `build` method constructs the UI. We use a `FadeTransition` widget, driven by our `_controller`, to animate the opacity of the `Text` widget.

```dart
// In _FadeInTextMeasureWidgetState

@override
Widget build(BuildContext context) {
  return Center(
    child: FadeTransition(
      opacity: _controller,
      child: Text(
        measure.text,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    ),
  );
}
```

### The `MeasureBuilderRegistry`: Tying it All Together

Now we have our `FadeInTextMeasure` data and the `FadeInTextMeasureWidget`. The `MeasureBuilderRegistry` connects them. It tells `AnecdoteWidget` which widget to build for which `Measure`.

```dart
// 1. Define your Anecdote using the new measure
class MyAnecdote implements Anecdote {
  const MyAnecdote();

  @override
  List<Measure> get measures => const [
    FadeInTextMeasure(text: 'This is a custom measure.', msDuration: 2000),
    FadeInTextMeasure(
      text: 'It fades in text with a custom animation.',
      msDuration: 2500,
    ),
    FadeInTextMeasure(
      text: 'This is the end of the anecdote.',
      msDuration: 3000,
    ),
  ];

  @override
  AudioSource? get musicSource => null;
}


// 2. Create a registry and register your measure type
final registry = MeasureBuilderRegistry();

registry.register<FadeInTextMeasure>(
  (context, measure) => FadeInTextMeasureWidget(measure: measure),
);

// 3. Use it in your app!
MaterialApp(
  home: Scaffold(
    body: AnecdoteWidget(
      anecdote: const MyAnecdote(),
      measureBuilderRegistry: registry,
    ),
  ),
);
```

When `AnecdoteWidget` encounters a `FadeInTextMeasure`, it will ask the registry for the correct builder and use it to create a `FadeInTextMeasureWidget`.

### Using Pre-Built Measures: `anecdotes_catalog`

Creating custom widgets for every scene is powerful, but a lot of work. For common scenarios, you can use the [anecdotes_catalog](https://github.com/Papi-Eruh/anecdotes_catalog) package, which provides ready-to-use measures and widgets for things like:

-   Displaying Rive animations
-   Showing world maps
-   ...and more!

Using them is just like using your own custom measure: you add them to your `measures` list and register their corresponding widgets from the catalog.

### Adding Layers: Audio, and Captions

Now that you understand the basics, let's add some flair.

#### Audio: Music and Voice-Overs

`AnecdoteWidget` can orchestrate background music and voice-overs.

-   **Background Music**: To play music for the *entire* anecdote, add an `AudioSource` to your `Anecdote`'s `musicSource` property and pass a `musicPlayer` to the `AnecdoteWidget`.
-   **Voice-Overs**: For audio that is specific to a *single scene*, add an `AudioSource` to the `voiceSource` property of a `Measure`.

This package does not handle audio playback itself. We recommend using a player package like [maestro_just_audio](https://github.com/Papi-Eruh/maestro_just_audio), which is designed to work seamlessly with `anecdotes`.

```dart
// 1. Define an anecdote with music
class MyMusicalStory implements Anecdote {
  @override
  final musicSource = AssetAudioSource('assets/audio/main_theme.mp3');

  @override
  List<Measure> get measures => [
    // This measure has its own voice-over
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
  anecdote: MyMusicalStory(),
  musicPlayer: maestro.musicPlayer,
  measureBuilderRegistry: registry,
)
```

#### Captions

To display subtitles synchronized with your audio, provide a `captionsSource` on a `Measure`. You'll also need to provide two builders to the `AnecdoteWidget`:

-   `captionBuilder`: A function that builds the widget to display the current caption text.
-   `CaptionsAdapter`: A class that knows how to parse your caption file format (e.g., JSON, SRT). The package provides a `JsonCaptionsAdapter` out of the box.

```dart
AnecdoteWidget(
  // ... other properties
  captionsAdapter: const JsonCaptionsAdapter(), // or your custom adapter
  captionBuilder: (context, caption) {
    if (caption == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomCenter,
      child: Text(caption.text),
    );
  },
)
```

### Displaying Multiple Stories with `AnecdoteCarousel`

What if you have more than one story to tell? The `AnecdoteCarousel` is a `PageView` that displays multiple `AnecdoteWidget`s in sequence, making it easy to create a playlist of anecdotes.

```dart
AnecdoteCarousel(
  anecdotes: [
    MyStory(measures: [/*...*/]),
    AnotherStory(measures: [/*...*/]),
  ],
  measureBuilderRegistry: registry,
)
```

You now have all the building blocks to create rich, engaging stories with Flutter. Happy storytelling!

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
