import 'dart:async';
import 'package:anecdotes/anecdotes.dart';
import 'package:anecdotes/src/widgets/anecdote_widget_impl.dart';
import 'package:heart/heart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/maestro.dart';

class M implements Measure {
  @override
  // TODO: implement captionsSource
  FileSource? get captionsSource => throw UnimplementedError();

  @override
  // TODO: implement id
  int get id => throw UnimplementedError();

  @override
  // TODO: implement voiceSource
  AudioSource? get voiceSource => throw UnimplementedError();
}

class LolTest extends StatefulWidget {
  const LolTest({super.key});

  @override
  State<LolTest> createState() => _LolTestState();
}

class _LolTestState extends State<LolTest> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class MeasureVoiceCompletedMixinImpl extends MeasureBaseWidget<M> {
  const MeasureVoiceCompletedMixinImpl({super.key, required super.measure});

  @override
  MeasureBaseState<MeasureBaseWidget<M>> createState() => _TestState();
}

class _TestState extends MeasureBaseState<MeasureBaseWidget<M>>
    with MeasureVoiceCompletedMixin {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }

  @override
  Future<void> prepareBeforeReady() async {}

  @override
  void onPause() {
    // TODO: implement onPause
  }

  @override
  void onPlay() {
    // TODO: implement onPlay
  }
}

void main() {
  group(
    '[MeasureVoiceCompletedMixin]',
    () {
      testWidgets(
        'With MeasureVoiceCompletedMixin should run',
        (tester) async {
          await tester.pumpWidget(
            MeasureWidgetProvider(
              controller: MeasureWidgetControllerImpl(),
              isPausedStream: Stream.value(false),
              onFinished: () {},
              onReady: () {},
              child: Builder(
                builder: (context) =>
                    MeasureVoiceCompletedMixinImpl(measure: M()),
              ),
            ),
          );
          await tester.pump();
          expect(find.byType(MeasureVoiceCompletedMixinImpl), findsOneWidget);
        },
      );
    },
  );
}
