import 'package:flutter/material.dart';
import 'package:RandomTierList/home/domain/model/network_track_model.dart';

class NetworkTrackItem extends StatelessWidget {
  final NetworkTrack track;
  final bool isCurrentlyPlaying;
  final bool isPlaying;
  final bool isDownloading;
  final bool isFavorite;
  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onLongPress;

  const NetworkTrackItem({
    super.key,
    required this.track,
    required this.isCurrentlyPlaying,
    required this.isPlaying,
    required this.isDownloading,
    required this.isFavorite,
    required this.onPlay,
    required this.onDownload,
    required this.onToggleFavorite,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isCurrentlyPlaying
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: ListTile(
        leading: Stack(
          children: [
            if (track.artworkUrl100 != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  track.artworkUrl100!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.music_note,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.music_note,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPlay,
                  borderRadius: BorderRadius.circular(8),
                  child: Center(
                    child: Icon(
                      isCurrentlyPlaying && isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: isCurrentlyPlaying
                          ? theme.colorScheme.primary
                          : Colors.white.withValues(alpha: 0.8),
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          track.trackName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight:
                isCurrentlyPlaying ? FontWeight.bold : FontWeight.normal,
            color: isCurrentlyPlaying ? theme.colorScheme.primary : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (track.artistName.isNotEmpty)
              Text(
                track.artistName,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  track.formattedDuration,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrentlyPlaying)
              Icon(
                Icons.graphic_eq,
                color: theme.colorScheme.primary,
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : null,
              ),
              onPressed: onToggleFavorite,
              tooltip:
                  isFavorite ? 'Удалить из избранного' : 'Добавить в избранное',
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              onPressed: isDownloading ? null : onDownload,
              tooltip: 'Скачать',
            ),
          ],
        ),
        onTap: onPlay,
        onLongPress: onLongPress,
        enableFeedback: false,
      ),
    );
  }
}
