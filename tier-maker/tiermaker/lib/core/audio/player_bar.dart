import 'package:flutter/material.dart';
import 'package:mumusic/core/audio/player_service.dart';

/// Обёртка для `MaterialApp.builder`: экран сверху, плашка плеера снизу.
///
/// `MaterialApp.builder` находится выше Navigator, поэтому своего Overlay
/// там нет, а он нужен слайдеру и тултипам. Заводим собственный Overlay
/// с одной записью и перестраиваем её при смене экрана.
class PlayerBarHost extends StatefulWidget {
  final Widget? child;

  const PlayerBarHost({super.key, required this.child});

  @override
  State<PlayerBarHost> createState() => _PlayerBarHostState();
}

class _PlayerBarHostState extends State<PlayerBarHost> {
  late final OverlayEntry _entry = OverlayEntry(builder: _buildContent);

  @override
  void didUpdateWidget(PlayerBarHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      // Нельзя помечать запись «грязной» во время build — откладываем
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _entry.markNeedsBuild();
      });
    }
  }

  Widget _buildContent(BuildContext context) {
    final player = PlayerService.instance;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final mediaQuery = MediaQuery.of(context);
        // Пока открыта клавиатура, плашку прячем, чтобы не отнимать место
        final showBar =
            player.current != null && mediaQuery.viewInsets.bottom == 0;
        final content = widget.child ?? const SizedBox.shrink();
        return Column(
          children: [
            Expanded(
              // Нижний системный отступ забирает плашка
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: showBar,
                child: content,
              ),
            ),
            if (showBar) const PlayerBar(),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(initialEntries: [_entry]);
  }
}

/// Плашка плеера внизу экрана. Одна на всё приложение
/// (подключается через [PlayerBarHost]), поэтому показывает
/// реальный текущий трек независимо от того, с какого экрана он запущен.
class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final player = PlayerService.instance;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final track = player.current;
        if (track == null) return const SizedBox.shrink();

        return Material(
          color: theme.colorScheme.surfaceContainerHighest,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              track.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              player.lastError ?? track.artist,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: player.lastError != null
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: theme.colorScheme.onSurfaceVariant,
                        onPressed: player.stop,
                      ),
                    ],
                  ),
                  const _ProgressRow(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: player.cycleSpeed,
                        child: Text(
                          '${_formatSpeed(player.speed)}x',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        iconSize: 32,
                        color: theme.colorScheme.onSurface,
                        onPressed: player.previous,
                      ),
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: player.isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child:
                                    CircularProgressIndicator(strokeWidth: 3),
                              )
                            : IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 48,
                                icon: Icon(
                                  player.isPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_filled,
                                  color: theme.colorScheme.secondary,
                                ),
                                onPressed: player.togglePlayPause,
                              ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        iconSize: 32,
                        color: theme.colorScheme.onSurface,
                        onPressed: player.hasNext ? player.next : null,
                      ),
                      // Место под симметрию с кнопкой скорости
                      const SizedBox(width: 48),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _formatSpeed(double speed) =>
      speed == speed.roundToDouble() ? speed.toStringAsFixed(1) : '$speed';
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow();

  @override
  Widget build(BuildContext context) {
    final player = PlayerService.instance;
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 12,
    );

    return ValueListenableBuilder<Duration>(
      valueListenable: player.position,
      builder: (context, position, _) {
        final total = player.duration;
        final max = total.inMilliseconds > 0
            ? total.inMilliseconds.toDouble()
            : 1.0;
        return Row(
          children: [
            Text(formatDuration(position), style: labelStyle),
            Expanded(
              child: Slider(
                value: position.inMilliseconds.toDouble().clamp(0.0, max),
                max: max,
                activeColor: theme.colorScheme.secondary,
                onChanged: total.inMilliseconds > 0
                    ? (v) => player.seek(Duration(milliseconds: v.toInt()))
                    : null,
              ),
            ),
            Text(formatDuration(total), style: labelStyle),
          ],
        );
      },
    );
  }
}

String formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
