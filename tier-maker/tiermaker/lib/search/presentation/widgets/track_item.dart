import 'package:flutter/material.dart';
import 'package:RandomTierList/domain/entities/track.dart';

class TrackItem extends StatelessWidget {
  final TrackEntity track;
  final bool isCurrentlyPlaying;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onFavorite;
  final VoidCallback? onTap;
  final bool showFavoriteButton;

  const TrackItem({
    super.key,
    required this.track,
    required this.isCurrentlyPlaying,
    required this.isPlaying,
    required this.onPlay,
    required this.onFavorite,
    this.onTap,
    this.showFavoriteButton = true,
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
            if (track.image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  track.highQualityImage,
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
                  track.trackTime,
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
            if (showFavoriteButton) ...[
              if (isCurrentlyPlaying) const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  track.favorite ? Icons.favorite : Icons.favorite_border,
                  color: track.favorite ? Colors.red : null,
                ),
                onPressed: onFavorite,
                tooltip: track.favorite
                    ? 'Удалить из избранного'
                    : 'Добавить в избранное',
              ),
            ],
          ],
        ),
        onTap: onTap ?? onPlay,
        enableFeedback: false,
      ),
    );
  }
}
