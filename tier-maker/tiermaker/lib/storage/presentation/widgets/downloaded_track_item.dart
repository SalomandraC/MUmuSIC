import 'package:flutter/material.dart';
import 'package:RandomTierList/home/domain/model/downloaded_track_model.dart';

class DownloadedTrackItem extends StatelessWidget {
  final DownloadedTrack track;
  final bool isCurrentlyPlaying;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  final VoidCallback? onLongPress;
  final VoidCallback? onUpload;
  final bool showUploadButton;
  final bool isUploading;

  const DownloadedTrackItem({
    super.key,
    required this.track,
    required this.isCurrentlyPlaying,
    required this.isPlaying,
    required this.onPlay,
    required this.onDelete,
    this.onLongPress,
    this.onUpload,
    this.showUploadButton = false,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isCurrentlyPlaying
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: ListTile(
          leading: Stack(
          children: [
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
            fontWeight: isCurrentlyPlaying ? FontWeight.bold : FontWeight.normal,
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
            Text(
              track.formattedDuration,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
            if (showUploadButton) ...[
              const SizedBox(width: 8),
              if (isUploading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (onUpload != null)
                IconButton(
                  icon: const Icon(Icons.cloud_upload),
                  onPressed: onUpload,
                  tooltip: 'Загрузить на сервер',
                ),
            ],
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
              tooltip: 'Удалить',
            ),
          ],
        ),
          onTap: onPlay,
          enableFeedback: false,
        ),
      ),
    );
  }
}

