import '../model/downloaded_track_model.dart';

/// Интерфейс репозитория для работы со скачанными треками
abstract class IDownloadedTracksRepository {
  /// Получить все скачанные треки
  Future<List<DownloadedTrack>> getDownloadedTracks();

  /// Удалить скачанный трек
  Future<void> deleteDownloadedTrack(DownloadedTrack track);
}

