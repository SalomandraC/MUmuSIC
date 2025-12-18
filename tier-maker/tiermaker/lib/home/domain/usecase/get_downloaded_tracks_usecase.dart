import '../model/downloaded_track_model.dart';
import '../repository/i_downloaded_tracks_repository.dart';

/// Use case для получения скачанных треков
class GetDownloadedTracksUseCase {
  final IDownloadedTracksRepository _repository;

  GetDownloadedTracksUseCase(this._repository);

  Future<List<DownloadedTrack>> execute() async {
    return await _repository.getDownloadedTracks();
  }
}

