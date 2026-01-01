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

Welcome to the `anecdotes` package! Let's build an anecdote together, one step at a time.

### 1. The Core Concepts: `Anecdote` and `Measure`

At its heart, an anecdote is simple. In this package:

-   An **`Anecdote`** is your story. It's a class that holds all the parts of your narrative.
-   A **`Measure`** is a single scene or step in your story. An `Anecdote` is composed of a list of `Measure`s.

Think of it like a movie: the `Anecdote` is the movie, and each `Measure` is a scene.

These are abstract classes. You'll create your own classes that implement them.

```dart
// 1. Define a class for our story
class MyStory implements Anecdote {
  @override
  final List<Measure> measures;

  MyStory({required this.measures});

  // We'll add music later
  @override
  final AudioSource? musicSource = null;
}

// 2. Define a class for a scene (we'll make a real one in a moment)
class MyFirstMeasure implements Measure {
  // We'll learn about these properties later
  @override
  final FileSource? captionsSource = null;
  @override
  final MeasureCompletionType completionType = MeasureCompletionType.custom;
  @override
  final AudioSource? voiceSource = null;
}
```

### 2. Bringing a Story to Life with `AnecdoteWidget`

The `AnecdoteWidget` is the stage where your story is performed. It takes an `Anecdote` and renders it.

But how does it know *what* to show for each `Measure`? It needs a little help.

### 3. Creating a Custom `Measure` Widget

To display a `Measure`, you need a corresponding widget. Let's create a simple one: a `Widget` that displays some text. This is the most basic way to create a scene.

**1. Define the `Measure` Data**

This class holds the data for our scene, in this case, just a string of text.

```dart
class SimpleTextMeasure implements Measure {
  const SimpleTextMeasure(this.text);
  final String text;

  // For now, we will control completion manually
  @override
  final completionType = MeasureCompletionType.custom;
  @override
  final voiceSource = null;
  @override
  final captionsSource = null;
}
```

**2. Create the `Measure` Widget and its `State`**

The `State` class is where the magic happens. It must extend `MeasureBaseState`, which gives you methods to control the scene's lifecycle.

For this simple example, we'll tell the `AnecdoteWidget` that our scene is "complete" after a 3-second delay.

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:anecdotes/anecdotes.dart';

// The Widget
class SimpleTextMeasureWidget extends MeasureBaseWidget<SimpleTextMeasure> {
  const SimpleTextMeasureWidget({super.key, required super.measure});

  @override
  MeasureBaseState<SimpleTextMeasure, SimpleTextMeasureWidget> createState() =>
      _SimpleTextMeasureWidgetState();
}

// The State
class _SimpleTextMeasureWidgetState
    extends MeasureBaseState<SimpleTextMeasure, SimpleTextMeasureWidget> {
  final _completer = Completer<void>();

  @override
  Future<void> prepareBeforeReady() async {
    // This is where you can do setup work, like initializing controllers.
    // In our case, we'll start a timer when the scene begins to play.
  }

  @override
  void onPlay() {
    // The AnecdoteWidget told us to start playing!
    // We'll complete this scene after 3 seconds.
    Future.delayed(const Duration(seconds: 3), () {
      if (!_completer.isCompleted) {
        _completer.complete();
      }
    });
  }

  @override
  Future<void> resolveCompletionCustom() {
    // AnecdoteWidget will wait for this Future to complete before moving on.
    return _completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(widget.measure.text));
  }
}
```

### 4. The `MeasureBuilderRegistry`: Tying it All Together

Now we have data (`SimpleTextMeasure`) and a widget (`SimpleTextMeasureWidget`). How do we connect them?

Enter the `MeasureBuilderRegistry`. This object tells `AnecdoteWidget` which widget to build for which `Measure`.

```dart
// 1. Create a registry
final registry = MeasureBuilderRegistry();

// 2. Register our custom measure type
registry.register<SimpleTextMeasure>(
  (context, measure) => SimpleTextMeasureWidget(measure: measure),
);

// 3. Now, we can use it!
AnecdoteWidget(
  anecdote: MyStory(
    measures: [
      SimpleTextMeasure('Hello, World!'),
      SimpleTextMeasure('This is Anecdotes.'),
    ],
  ),
  measureBuilderRegistry: registry,
);
```

When `AnecdoteWidget` encounters a `SimpleTextMeasure`, it will ask the registry for the correct builder and use it to create a `SimpleTextMeasureWidget`.

### 5. Using Pre-Built Measures: `anecdotes_catalog`

Creating custom widgets for every scene is powerful, but a lot of work. For common scenarios, you can use the [anecdotes_catalog](https://github.com/Papi-Eruh/anecdotes_catalog) package, which provides ready-to-use measures and widgets for things like:

-   Displaying Rive animations
-   Showing world maps
-   ...and more!

Using them is just like using your own custom measure: you add them to your `measures` list and register their corresponding widgets from the catalog.

### 6. Adding Layers: Audio, Captions, and Completion Control

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

#### Controlling the Flow: Measure Completion

How does `AnecdoteWidget` know when to move to the next scene? You tell it by setting the `completionType` on your `Measure`.

1.  **Declarative Completion**: The easy way. Let the audio decide.
    -   `MeasureCompletionType.voice`: The scene ends when the `voiceSource` finishes playing.
    -   `MeasureCompletionType.music`: The scene ends when its corresponding track in the `musicSource` playlist finishes.

    ```dart
    // From the anecdotes_catalog, this measure will end when its music track ends.
    const WorldMapMeasure(
      countryCode: 'FR',
      completionType: MeasureCompletionType.music,
    )
    ```

2.  **Programmatic Completion**: The flexible way. You decide.
    -   `MeasureCompletionType.custom`: You are in full control.
    -   In your `MeasureBaseState`, you must override the `resolveCompletionCustom()` method.
    -   This method should return a `Future` that completes whenever your scene's work is done (e.g., an animation has finished, a timer has elapsed, or the user tapped a button).
    -   Our `SimpleTextMeasureWidget` example from earlier used this approach with a `Completer`.

### 7. Displaying Multiple Stories with `AnecdoteCarousel`

What if you have more than one story to tell? The `AnecdoteCarousel` is a `PageView` that displays multiple `AnecdoteWidget`s in sequence, making it easy to create a playlist of anecdotes.

```dart
AnecdoteCarousel(
  anecdotes: [
    MyStory(measures: [/*...*/]),
    AnotherStory(measures: [/*...*/]),
  ],
  measureBuilderRegistry: registry,
  // You can also pass a musicPlayer, captionBuilder, etc.
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
