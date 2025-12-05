import 'package:RandomTierList/home/domain/model/network_track_model.dart';

/// Интерфейс репозитория для работы с треками из сети
abstract interface class INetworkRepository {
  /// Поиск треков по запросу
  /// 
  /// [query] - поисковый запрос
  /// [limit] - максимальное количество результатов
  /// 
  /// Возвращает список найденных треков
  Future<List<NetworkTrack>> searchTracks({
    required String query,
    int limit = 50,
  });

  /// Скачивание трека
  /// 
  /// [track] - трек для скачивания
  /// 
  /// Возвращает путь к скачанному файлу
  Future<String> downloadTrack(NetworkTrack track);

  /// Предпрослушивание трека
  /// 
  /// [track] - трек для предпрослушивания
  /// 
  /// Возвращает URL для предпрослушивания
  String? getPreviewUrl(NetworkTrack track);
}

