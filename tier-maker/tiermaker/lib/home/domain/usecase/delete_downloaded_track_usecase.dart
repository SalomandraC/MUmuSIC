import '../model/downloaded_track_model.dart';
import '../repository/i_downloaded_tracks_repository.dart';

/// Use case для удаления скачанного трека
class DeleteDownloadedTrackUseCase {
  final IDownloadedTracksRepository _repository;

  DeleteDownloadedTrackUseCase(this._repository);

  Future<void> execute(DownloadedTrack track) async {
    await _repository.deleteDownloadedTrack(track);
  }
}

