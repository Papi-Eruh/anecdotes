import 'dart:async';

import 'package:anecdotes/anecdotes.dart';
import 'package:heart/heart.dart' hide Anecdote;
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
class AnecdoteCarousel extends StatefulWidget {
  /// const constructor
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
  /// If not provided, a new [AnecdoteWidgetController] will be created.
  final AnecdoteWidgetController? firstController;

  /// The list of anecdotes to display in the carousel.
  final List<Anecdote> anecdotes;

  /// Registry that provides builder functions for different [Measure] types.
  final MeasureBuilderRegistry measureBuilderRegistry;

  /// Adapter used to parse caption data from files.
  final CaptionsAdapter captionsAdapter;

  /// Defines the scroll direction of the carousel (vertical or horizontal).
  final Axis scrollDirection;

  /// Whether anecdotes should loop when reaching the end.
  final bool loop;

  /// Whether the anecdotes are interactive (e.g., respond to user input).
  final bool isInteractive;

  /// The shared [MusicPlayer] instance used for background or ambient sounds.
  final MusicPlayer? musicPlayer;

  /// Called when all anecdotes have finished playing.
  final VoidCallback? onEnd;

  /// Whether to add an extra empty child [SizedBox.shrink] at the end
  /// of the carousel to allow triggering [onEnd] when it is reached.
  final bool hasEndChild;

  /// Callback invoked each time an individual anecdote finishes.
  final AnecdoteCallback? onAnecdoteFinished;

  /// Builder for creating a custom voice player.
  final VoicePlayerBuilder? voicePlayerBuilder;

  /// Builder for creating a custom pause widget overlay.
  final PauseWidgetBuilder? pauseWidgetBuilder;

  /// Builder for rendering custom caption widgets.
  final CaptionsWidgetBuilder? captionsWidgetBuilder;

  /// Page controller used in the [PageView]
  final PageController? pageController;

  /// If true, show the captions.
  final bool isCaptionsVisible;

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
              onReady: ifThen(
                i: index == 0 && _providedFirstController == null,
                t: _startFirstAnc,
              ),
              musicPlayer: _musicPlayer,
              musicBehavior: behaviorSnapshot.data,
              voicePlayerBuilder: widget.voicePlayerBuilder,
              loop: widget.loop,
              onFinished: ifThen(
                i: onAnecdoteFinished != null,
                t: () => onAnecdoteFinished?.call(index, anecdote),
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
