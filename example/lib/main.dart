import 'dart:async';

import 'package:anecdotes/anecdotes.dart';
import 'package:flutter/material.dart';

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
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: measure.msDuration),
    );
    _controller.addStatusListener(_onAnimationStatusChanged);
  }

  @override
  Future<void> resolveCompletionCustom() {
    return _completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            measure.text,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

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

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _registry = MeasureBuilderRegistry();

  @override
  void initState() {
    super.initState();
    _registry.register<FadeInTextMeasure>(
      (context, measure) => FadeInTextMeasureWidget(measure: measure),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: AnecdoteWidget(
          anecdote: const MyAnecdote(),
          measureBuilderRegistry: _registry,
        ),
      ),
    );
  }
}

