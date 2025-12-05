import 'package:RandomTierList/home/domain/model/network_track_model.dart';
import 'package:RandomTierList/home/domain/repository/i_network_repository.dart';

/// Use case для поиска треков в сети
class SearchTracksUseCase {
  final INetworkRepository _repository;

  SearchTracksUseCase(this._repository);

  /// Выполнить поиск треков
  /// 
  /// [query] - поисковый запрос
  /// [limit] - максимальное количество результатов
  /// 
  /// Возвращает список найденных треков
  Future<List<NetworkTrack>> execute({
    required String query,
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    return await _repository.searchTracks(
      query: query,
      limit: limit,
    );
  }
}

