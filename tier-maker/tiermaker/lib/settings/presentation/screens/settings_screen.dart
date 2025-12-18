import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';    
import 'package:RandomTierList/core/global_widgets/panel_header.dart';
import 'package:RandomTierList/settings/presentation/providers/settings_provider.dart';
import 'package:RandomTierList/theme/theme.dart';
import 'package:RandomTierList/settings/presentation/widgets/setting_support_functions.dart';
import 'package:RandomTierList/core/services/upload_service.dart';
import 'package:RandomTierList/core/services/download_service.dart';
import 'package:RandomTierList/home/domain/repository/downloaded_tracks_repository_impl.dart';
import 'package:RandomTierList/home/domain/usecase/get_downloaded_tracks_usecase.dart';
import 'package:RandomTierList/home/domain/model/downloaded_track_model.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsModel = SettingsProvider.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            PanelHeader(
              name: 'Настройки',
              showBackButton: true,
              textColor: theme.colorScheme.primary,
              onBackClick: () => context.pop(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  children: [
                    SettingsItem(
                      text: settingsModel.appModel.isDarkTheme
                          ? 'Темная тема'
                          : 'Светлая тема',
                      trailing: Switch(
                        value: settingsModel.appModel.isDarkTheme,
                        onChanged: (value) {
                          settingsModel.setTheme(value);
                        },
                        thumbColor: MaterialStateProperty.resolveWith<Color>(
                          (Set<MaterialState> states) {
                            if (states.contains(MaterialState.selected)) {
                              return settingsModel.appModel.isDarkTheme
                                  ? AppTheme.primaryColorLight
                                  : AppTheme.primaryColor; 
                            }
                            return Colors.grey.shade400;
                          },
                        ),
                        trackColor: MaterialStateProperty.resolveWith<Color>(
                          (Set<MaterialState> states) {
                            if (states.contains(MaterialState.selected)) {
                              return (settingsModel.appModel.isDarkTheme
                                      ? AppTheme.primaryColorLight
                                      : AppTheme.primaryColor)
                                  .withOpacity(0.5);
                            }
                            return Colors.grey.withOpacity(0.3);
                          },
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    SettingsItem(
                      text: 'Поделиться приложением',
                      icon: Icons.share,
                      onTap: () => shareApp(context),
                    ),        
                    SettingsItem(
                      text: 'Связаться с поддержкой',
                      icon: Icons.support_agent,
                      onTap: () => contactSupport(context),
                    ),
                    SettingsItem(
                      text: 'Пользовательское соглашение',
                      icon: Icons.arrow_forward_ios,
                      onTap: () => openUserAgreement(context),
                    ),
                    SettingsItem(
                      text: 'Настройка API сервера',
                      icon: Icons.settings_ethernet,
                      onTap: () => showApiUrlSettings(context),
                    ),
                    SettingsItem(
                      text: 'Тест подключения к бэкенду',
                      icon: Icons.cloud_sync,
                      onTap: () => testBackendConnection(context),
                    ),
                    if (!settingsModel.appModel.isGuest) ...[
                      const Divider(),
                      SettingsItem(
                        text: 'Синхронизация данных',
                        icon: Icons.cloud_upload,
                        onTap: () => _showSyncDialog(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSyncDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SyncDialog(),
    );
  }
}

class SyncDialog extends StatefulWidget {
  const SyncDialog({super.key});

  @override
  State<SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<SyncDialog> {
  bool _isLoading = false;
  String? _currentStep;
  int _currentProgress = 0;
  int _totalProgress = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Синхронизация данных'),
      content: _isLoading
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_currentStep != null) ...[
                  Text(_currentStep!),
                  const SizedBox(height: 16),
                ],
                if (_totalProgress > 0) ...[
                  LinearProgressIndicator(
                    value: _currentProgress / _totalProgress,
                  ),
                  const SizedBox(height: 8),
                  Text('$_currentProgress / $_totalProgress'),
                ] else
                  const CircularProgressIndicator(),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Выберите действие:'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _downloadTracks(context),
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('Подгрузить треки с сервера'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _downloadPlaylists(context),
                    icon: const Icon(Icons.playlist_play),
                    label: const Text('Подгрузить плейлисты с сервера'),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text('Загрузка данных на сервер:'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _uploadPlaylists(context),
                    icon: const Icon(Icons.playlist_play),
                    label: const Text('Загрузить плейлисты'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _uploadAllData(context),
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Загрузить все данные'),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }

  Future<void> _downloadTracks(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _currentStep = 'Загрузка треков с сервера...';
    });

    try {
      final result = await _downloadTracksData();
      if (!mounted) return;

      Navigator.of(context).pop();
      _showResult(context, result, 'Треки');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadPlaylists(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _currentStep = 'Загрузка плейлистов с сервера...';
    });

    try {
      final result = await _downloadPlaylistsData();
      if (!mounted) return;

      Navigator.of(context).pop();
      _showResult(context, result, 'Плейлисты');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _uploadPlaylists(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _currentStep = 'Загрузка плейлистов...';
    });

    try {
      final result = await _uploadPlaylistsData();
      if (!mounted) return;

      Navigator.of(context).pop();
      _showResult(context, result, 'Плейлисты');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _uploadAllData(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _currentStep = 'Подготовка...';
    });

    try {
      final result = await _uploadAllDataToServer();
      if (!mounted) return;

      Navigator.of(context).pop();
      _showResult(context, result, 'Все данные');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _downloadTracksData() async {
    return await DownloadService.downloadTracks();
  }

  Future<Map<String, dynamic>> _downloadPlaylistsData() async {
    return await DownloadService.downloadPlaylists();
  }

  Future<Map<String, dynamic>> _uploadPlaylistsData() async {
    return await UploadService.uploadPlaylists();
  }

  Future<Map<String, dynamic>> _uploadAllDataToServer() async {
    setState(() {
      _currentStep = 'Получение треков из хранилища...';
    });

    final downloadedTracks = await _getDownloadedTracks();
    
    setState(() {
      _totalProgress = downloadedTracks.length;
      _currentProgress = 0;
    });

    return await UploadService.uploadAllData(
      tracks: downloadedTracks,
      onStep: (step) {
        if (mounted) {
          setState(() {
            _currentStep = step;
          });
        }
      },
      onProgress: (current, total) {
        if (mounted) {
          setState(() {
            _currentProgress = current;
            _totalProgress = total;
          });
        }
      },
    );
  }

  Future<List<DownloadedTrack>> _getDownloadedTracks() async {
    final repository = DownloadedTracksRepositoryImpl();
    final useCase = GetDownloadedTracksUseCase(repository);
    return await useCase.execute();
  }

  void _showResult(BuildContext context, Map<String, dynamic> result, String dataType) {
    final success = result['success'] == true;
    String message;
    
    if (result['results'] != null) {
      // Результат загрузки всех данных
      final results = result['results'] as Map<String, dynamic>;
      final tracksResult = results['tracks'] as Map<String, dynamic>?;
      final playlistsResult = results['playlists'] as Map<String, dynamic>?;
      
      final parts = <String>[];
      if (tracksResult != null) {
        final successCount = tracksResult['successCount'] as int? ?? 0;
        final failCount = tracksResult['failCount'] as int? ?? 0;
        parts.add('Треки: $successCount успешно, $failCount ошибок');
      }
      if (playlistsResult != null && playlistsResult['success'] == true) {
        parts.add('Плейлисты: загружены');
      }
      
      message = parts.isEmpty 
          ? 'Данные успешно загружены'
          : parts.join('\n');
    } else {
      message = result['message'] as String? ?? 
               result['error'] as String? ?? 
               (success ? 'Данные успешно загружены' : 'Ошибка загрузки');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

class SettingsItem extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsItem({
    super.key,
    required this.text,
    this.icon,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 61,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            if (trailing != null)
              trailing!
            else if (icon != null)
              Icon(
                icon,
                size: 24,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

