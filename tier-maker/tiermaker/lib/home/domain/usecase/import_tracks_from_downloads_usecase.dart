import '../model/downloaded_track_model.dart';
import '../repository/i_downloaded_tracks_repository.dart';

/// Use case для импорта аудиофайлов из папки «Загрузки» телефона
/// во внутреннее хранилище приложения
class ImportTracksFromDownloadsUseCase {
  final IDownloadedTracksRepository _repository;

  ImportTracksFromDownloadsUseCase(this._repository);

  /// Список треков в «Загрузках», которых ещё нет в хранилище
  Future<List<DownloadedTrack>> findImportable() async {
    return await _repository.getImportableTracks();
  }

  /// Скопировать выбранные треки, вернуть количество скопированных
  Future<int> execute(List<DownloadedTrack> tracks) async {
    return await _repository.importTracks(tracks);
  }
}
