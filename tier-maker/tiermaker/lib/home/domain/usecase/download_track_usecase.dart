import 'package:RandomTierList/home/domain/model/network_track_model.dart';
import 'package:RandomTierList/home/domain/repository/i_network_repository.dart';

/// Use case для скачивания трека
class DownloadTrackUseCase {
  final INetworkRepository _repository;

  DownloadTrackUseCase(this._repository);

  /// Скачать трек
  /// 
  /// [track] - трек для скачивания
  /// 
  /// Возвращает путь к скачанному файлу
  Future<String> execute(NetworkTrack track) async {
    return await _repository.downloadTrack(track);
  }
}

