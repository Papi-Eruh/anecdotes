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

### Example Scenario

Let's create an anecdote with two scenes:

1.  **Scene 1**: Show a map focused on Jamaica.
2.  **Scene 2**: Display a looping Rive animation of pirates.

We'll use `WorldMapMeasure` and `LoopingRiveMeasure` from the `anecdotes_catalog` package.

Here’s the correct way to implement this:

```dart
final measureRegistry = MeasureBuilderRegistry()
  ..register<WorldMapMeasure>(
    (context, measure) => WorldMapMeasureWidget(measure: measure),
  )
  ..register<LoopingRiveMeasure>(
    (context, measure) => LoopingRiveMeasureWidget(measure: measure),
  );

class PirateAnecdote implements Anecdote {
  const PirateAnecdote();

  @override
  final AudioSource? musicSource = null;

  @override
  List<Measure> get measures => const [
        WorldMapMeasure(
          id: 1,
          countryCode: 'JM',
        ),
        LoopingRiveMeasure(
          id: 2,
          riveSource: FileSource('assets/animations/pirates.riv'),
        ),
      ];
}

void main() {
  // Make sure to have your assets in pubspec.yaml
  // assets:
  //   - assets/animations/pirates.riv
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anecdote Demo',
      home: Scaffold(
        body: AnecdoteWidget(
          anecdote: const PirateAnecdote(),
          measureBuilderRegistry: measureRegistry,
        ),
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
    this.style,
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
  final TextStyle? style;
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: measure.msDuration));
  }

  @override
  void dispose() {
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
    // Perform any async setup here before the widget is shown.
  }

  @override
  Future<void> resolveCompletion() {
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_completer.isCompleted) {
        _completer.complete();
      }
    });
    return _completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Center(
        child: Text(measure.text, style: measure.style),
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
