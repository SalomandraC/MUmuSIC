import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:RandomTierList/core/global_widgets/panel_header.dart';
import 'package:RandomTierList/domain/entities/playlist.dart';
import 'package:RandomTierList/domain/repositories/playlists_repository.dart';
import 'package:RandomTierList/domain/usecases/create_playlist_usecase.dart';
import 'package:RandomTierList/di/dependency_injection.dart';
import 'package:RandomTierList/playlists/presentation/widgets/playlist_item.dart';
import 'package:RandomTierList/app/app_routes.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  final PlaylistsRepository _playlistsRepository =
      DependencyInjection.playlistsRepository;
  final CreatePlaylistUseCase _createPlaylistUseCase =
      DependencyInjection.createPlaylistUseCase;

  List<PlaylistEntity> _playlists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    setState(() {
      _isLoading = true;
    });

    final playlists = await _playlistsRepository.getAllPlaylists();
    setState(() {
      _playlists = playlists;
      _isLoading = false;
    });
  }

  Future<void> _createPlaylist() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать плейлист'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Название',
                hintText: 'Введите название плейлиста',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Описание',
                hintText: 'Введите описание (необязательно)',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      await _createPlaylistUseCase.execute(
        name: nameController.text.trim(),
        description: descriptionController.text.trim(),
      );
      await _loadPlaylists();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PanelHeader(
              name: 'Плейлисты',
              showBackButton: true,
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _playlists.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.library_music,
                                  size: 64,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Нет плейлистов',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16.0),
                            itemCount: _playlists.length,
                            itemBuilder: (context, index) {
                              final playlist = _playlists[index];
                              return PlaylistItem(
                                playlist: playlist,
                                onTap: () {
                                  context.pushNamed(
                                    AppRoutes.playlistDetailsName,
                                    pathParameters: {
                                      'id': playlist.id.toString()
                                    },
                                  );
                                },
                                onDelete: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Удалить плейлист?'),
                                      content: Text(
                                        'Вы уверены, что хотите удалить плейлист "${playlist.name}"?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text('Отмена'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          child: const Text('Удалить'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await _playlistsRepository.deletePlaylist(
                                      playlist.id,
                                    );
                                    await _loadPlaylists();
                                  }
                                },
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createPlaylist,
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.onSecondary,
        child: const Icon(Icons.add),
      ),
    );
  }
}
