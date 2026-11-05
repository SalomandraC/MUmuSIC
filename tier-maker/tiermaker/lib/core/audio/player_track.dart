/// Трек в очереди воспроизведения.
///
/// Единая модель для всех экранов: поиск, избранное, плейлисты,
/// хранилище, сеть, чарты и NFC приводят свои модели к ней.
class PlayerTrack {
  /// Уникальный ключ трека в очереди (используется для подсветки в списках)
  final String id;
  final String title;
  final String artist;

  /// http(s) URL или путь к локальному файлу.
  /// Может быть пустым, если URL получается лениво через [resolveSource].
  final String source;
  final String? artworkUrl;

  /// Ленивое получение адреса потока (например, запрос к серверу).
  final Future<String> Function()? resolveSource;

  const PlayerTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.source = '',
    this.artworkUrl,
    this.resolveSource,
  });

  bool get hasSource => source.isNotEmpty || resolveSource != null;
}
