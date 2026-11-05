import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mumusic/core/audio/player_bar.dart';
import 'package:mumusic/core/audio/player_service.dart';
import 'package:mumusic/core/audio/player_track.dart';

/// Нативной части audioplayers в тестах нет: отвечаем на вызовы пустотой,
/// а на setSourceUrl присылаем событие «готово», как это делает Android.
void _mockAudioplayers() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = StandardMethodCodec();
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global'),
    (call) async => null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (call) async {
      final args = call.arguments as Map<Object?, Object?>?;
      final id = args?['playerId'];
      if (id != null) {
        final channel = 'xyz.luan/audioplayers/events/$id';
        messenger.setMockMethodCallHandler(
            MethodChannel(channel), (call) async => null);
        if (call.method == 'setSourceUrl') {
          Future<void>.delayed(Duration.zero, () {
            messenger.handlePlatformMessage(
              channel,
              codec.encodeSuccessEnvelope(
                  {'event': 'audio.onPrepared', 'value': true}),
              (_) {},
            );
          });
        }
      }
      return null;
    },
  );
}

PlayerTrack _track(int i) => PlayerTrack(
      id: 't$i',
      title: 'Трек $i',
      artist: 'Артист $i',
      source: 'https://example.com/$i.mp3',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _mockAudioplayers();

  final player = PlayerService.instance;
  final queue = [_track(1), _track(2), _track(3)];

  tearDown(() => player.stop());

  test('текущий трек меняется сразу, без ожидания конца трека', () async {
    final future = player.playQueue(queue, 0);
    // Ещё до завершения загрузки UI уже видит новый трек
    expect(player.current?.id, 't1');
    await future;
    expect(player.current?.id, 't1');
  });

  test('вперёд/назад идут по очереди одним нажатием', () async {
    await player.playQueue(queue, 0);
    await player.next();
    expect(player.current?.title, 'Трек 2');
    await player.next();
    expect(player.current?.title, 'Трек 3');
    expect(player.hasNext, isFalse);
    await player.previous();
    expect(player.current?.title, 'Трек 2');
  });

  test('быстрые переключения: побеждает последнее нажатие', () async {
    var resolved = 0;
    final slow = PlayerTrack(
      id: 'slow',
      title: 'Медленный',
      artist: '',
      resolveSource: () async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        resolved++;
        return 'https://example.com/slow.mp3';
      },
    );
    final first = player.playQueue([slow, _track(9)], 0);
    final second = player.playQueue([slow, _track(9)], 1);
    await Future.wait([first, second]);
    expect(player.current?.id, 't9');
    expect(player.isLoading, isFalse);
    expect(resolved, 1);
  });

  test('нажатие на текущий трек в списке не перезапускает очередь', () async {
    await player.toggleFromList(queue, 1);
    expect(player.index, 1);
    await player.toggleFromList(queue, 1);
    expect(player.current?.id, 't2');
  });

  test('удаление текущего трека останавливает плеер', () async {
    await player.playQueue(queue, 0);
    await player.removeTrack('t2');
    expect(player.queue.length, 2);
    await player.removeTrack('t1');
    expect(player.current, isNull);
  });

  testWidgets('плашка показывает текущий трек поверх любого экрана',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => PlayerBarHost(child: child),
        home: const Scaffold(body: Text('Экран')),
      ),
    );
    expect(find.text('Трек 1'), findsNothing);

    await tester.runAsync(() => player.playQueue(queue, 0));
    await tester.pump();
    expect(find.text('Трек 1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.text('Трек 2'), findsOneWidget);

    await tester.runAsync(() => player.stop());
    await tester.pump();
    expect(find.text('Трек 2'), findsNothing);
  });
}
