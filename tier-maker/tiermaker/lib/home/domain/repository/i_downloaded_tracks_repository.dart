import '../model/downloaded_track_model.dart';

/// Интерфейс репозитория для работы со скачанными треками
abstract class IDownloadedTracksRepository {
  /// Получить все скачанные треки
  Future<List<DownloadedTrack>> getDownloadedTracks();

  /// Удалить скачанный трек
  Future<void> deleteDownloadedTrack(DownloadedTrack track);

  /// Найти аудиофайлы в папке «Загрузки» телефона, которых ещё нет
  /// во внутреннем хранилище приложения
  Future<List<DownloadedTrack>> getImportableTracks();

  /// Скопировать выбранные файлы из «Загрузок» во внутреннее хранилище.
  /// Возвращает количество успешно скопированных файлов
  Future<int> importTracks(List<DownloadedTrack> tracks);
}

