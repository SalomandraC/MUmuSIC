import 'package:flutter/material.dart';
import 'package:RandomTierList/domain/entities/playlist.dart';

class PlaylistItem extends StatelessWidget {
  final PlaylistEntity playlist;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const PlaylistItem({
    super.key,
    required this.playlist,
    required this.onTap,
    required this.onDelete,
  });

  String _getTrackCountText(int count) {
    if (count == 0) return 'Нет треков';
    final lastDigit = count % 10;
    final lastTwoDigits = count % 100;
    
    if (lastTwoDigits >= 11 && lastTwoDigits <= 14) {
      return '$count треков';
    } else if (lastDigit == 1) {
      return '$count трек';
    } else if (lastDigit >= 2 && lastDigit <= 4) {
      return '$count трека';
    } else {
      return '$count треков';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: playlist.coverImageUri != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  playlist.coverImageUri!,
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
                        Icons.library_music,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              )
            : Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.library_music,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
        title: Text(
          playlist.name,
          style: theme.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _getTrackCountText(playlist.tracks.length),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
          tooltip: 'Удалить плейлист',
        ),
        onTap: onTap,
      ),
    );
  }
}

