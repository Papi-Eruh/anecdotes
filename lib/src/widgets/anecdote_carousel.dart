import 'dart:async';

import 'package:anecdotes/src/internals/internals.dart';
import 'package:anecdotes/src/models/models.dart';
import 'package:anecdotes/src/widgets/anecdote_widget.dart';
import 'package:flutter/material.dart';
import 'package:maestro/maestro.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Signature for a callback invoked when an [Anecdote] has finished playing.
///
/// The [index] corresponds to the position of the anecdote within the carousel,
/// and [anecdote] is the completed instance.
typedef AnecdoteCallback = void Function(int index, Anecdote anecdote);

/// A widget that displays a list of [AnecdoteWidget]s using a [PageView].
///
/// This widget allows users to navigate through multiple anecdotes,
/// either vertically or horizontally.
/// Each anecdote manages its own controller, audio playback, and visuals.
///
/// ```dart
/// AnecdoteCarousel(
///   anecdotes: myAnecdotes,
///   measureBuilderRegistry: myMeasureBuilderRegistry,
///   onEnd: () => print('Finished all anecdotes!'),
/// )
/// ```
class AnecdoteCarousel extends StatefulWidget {
  /// Creates a carousel for displaying anecdotes.
  const AnecdoteCarousel({
    required this.anecdotes,
    required this.measureBuilderRegistry,
    super.key,
    this.scrollDirection = Axis.vertical,
    this.loop = false,
    this.isInteractive = true,
    this.captionsAdapter = const JsonCaptionsAdapter(),
    this.firstController,
    this.musicPlayer,
    this.onEnd,
    this.onAnecdoteFinished,
    this.voicePlayerBuilder,
    this.pauseWidgetBuilder,
    this.captionsWidgetBuilder,
    this.pageController,
    this.isCaptionsVisible = true,
    this.hasEndChild = false,
  });

  /// Optional controller for the first anecdote.
  ///
  /// If not provided, a new [AnecdoteWidgetController] will be created
  /// internally.
  final AnecdoteWidgetController? firstController;

  /// The ordered list of anecdotes to be displayed in the carousel.
  final List<Anecdote> anecdotes;

  /// A registry that provides builder functions for different types of
  /// [Measure].
  ///
  /// This allows for custom rendering of different measure types.
  final MeasureBuilderRegistry measureBuilderRegistry;

  /// An adapter responsible for parsing caption data from [FileSource].
  ///
  /// Defaults to [JsonCaptionsAdapter].
  final CaptionsAdapter captionsAdapter;

  /// The direction in which the carousel scrolls.
  ///
  /// Defaults to [Axis.vertical].
  final Axis scrollDirection;

  /// Determines whether the carousel should loop back to the beginning after
  /// the last anecdote.
  ///
  /// Defaults to `false`.
  final bool loop;

  /// Determines whether the anecdotes are interactive.
  ///
  /// If `true`, user interactions (like taps) can control playback.
  /// Defaults to `true`.
  final bool isInteractive;

  /// A shared [MusicPlayer] instance for handling background music across
  /// anecdotes.
  final MusicPlayer? musicPlayer;

  /// A callback that is invoked when the user reaches the end of the carousel.
  ///
  /// This is typically used to trigger navigation or other actions when all
  /// anecdotes have been viewed.
  final VoidCallback? onEnd;

  /// A callback that is invoked each time an individual anecdote finishes
  /// playing.
  final AnecdoteCallback? onAnecdoteFinished;

  /// An optional builder for creating a custom voice player widget.
  final VoicePlayerBuilder? voicePlayerBuilder;

  /// An optional builder for creating a custom widget to be displayed when
  /// playback is paused.
  final PauseWidgetBuilder? pauseWidgetBuilder;

  /// An optional builder for rendering custom caption widgets.
  final CaptionsWidgetBuilder? captionsWidgetBuilder;

  /// An optional controller for the underlying [PageView].
  ///
  /// If not provided, a [PageController] will be created internally.
  final PageController? pageController;

  /// Determines whether captions should be visible.
  ///
  /// Defaults to `true`.
  final bool isCaptionsVisible;

  /// If `true`, an extra empty child is added at the end of the carousel.
  ///
  /// This allows the [onEnd] callback to be triggered when the user scrolls
  /// to the final page. Defaults to `false`.
  final bool hasEndChild;

  @override
  State<AnecdoteCarousel> createState() => _AnecdoteCarouselState();
}

class _AnecdoteCarouselState extends State<AnecdoteCarousel> {
  final _musicBehaviorStreamCtrl = StreamController<AncMusicBehavior>();
  late final _controllerByIndex = <int, AnecdoteWidgetController?>{
    0: _providedFirstController ?? AnecdoteWidgetController(),
    ...List.generate(
      _anecdotes.length - 1,
      (index) => index + 1,
    ).toMapItemKey((_) => AnecdoteWidgetController()),
  };

  var _hasStartedInternally = false;

  MusicPlayer? get _musicPlayer => widget.musicPlayer;

  AnecdoteWidgetController? get _providedFirstController {
    return widget.firstController;
  }

  List<Anecdote> get _anecdotes => widget.anecdotes;

  PageController? get _pageController => widget.pageController;

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable());
  }

  @override
  void dispose() {
    final firstController = _controllerByIndex[0];
    if (firstController?.isStarted ?? false) unawaited(_musicPlayer?.pop());
    unawaited(_musicBehaviorStreamCtrl.close());
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  void _startFirstAnc() {
    if (_hasStartedInternally) return;
    _controllerByIndex[0]?.start();
    _hasStartedInternally = true;
    _musicBehaviorStreamCtrl.add(AncMusicBehavior.replace);
  }

  void _onPageChanged(int page) {
    if (page == _anecdotes.length) return widget.onEnd?.call();
    _controllerByIndex[page]?.start();
  }

  @override
  Widget build(BuildContext context) {
    final onAnecdoteFinished = widget.onAnecdoteFinished;
    final hasEndChild = widget.hasEndChild;
    return StreamBuilder(
      initialData: AncMusicBehavior.push,
      stream: _musicBehaviorStreamCtrl.stream,
      builder: (context, behaviorSnapshot) {
        return PageView.builder(
          controller: _pageController,
          scrollDirection: widget.scrollDirection,
          onPageChanged: _onPageChanged,
          itemCount: _anecdotes.length + (hasEndChild ? 1 : 0),
          itemBuilder: (context, index) {
            if (hasEndChild && index == _anecdotes.length) {
              return const SizedBox.shrink();
            }
            final anecdote = widget.anecdotes[index];
            return AnecdoteWidget(
              controller: _controllerByIndex[index],
              anecdote: anecdote,
              measureBuilderRegistry: widget.measureBuilderRegistry,
              onReady: (index == 0 && _providedFirstController == null).then(
                _startFirstAnc,
              ),
              musicPlayer: _musicPlayer,
              musicBehavior: behaviorSnapshot.data,
              voicePlayerBuilder: widget.voicePlayerBuilder,
              loop: widget.loop,
              onFinished: (onAnecdoteFinished != null).then(
                () => onAnecdoteFinished?.call(index, anecdote),
              ),
              pauseWidgetBuilder: widget.pauseWidgetBuilder,
              captionsAdapter: widget.captionsAdapter,
              captionsWidgetBuilder: widget.captionsWidgetBuilder,
              isInteractive: widget.isInteractive,
              isWakelockedManaged: false,
              isCaptionsVisible: widget.isCaptionsVisible,
            );
          },
        );
      },
    );
  }
}
