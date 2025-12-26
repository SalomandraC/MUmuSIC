# Документация клиентского приложения

## app

Модуль конфигурации и инициализации приложения. Управляет глобальным состоянием приложения, темой, языком и аутентификацией пользователя.

### my_app.dart

Главный виджет приложения. Инициализирует роутер, провайдеры состояния и настраивает тему приложения на основе `AppModel`.

```dart
class TierMakerApp extends StatefulWidget {
  final AppModel appModel;

  const TierMakerApp({
    super.key,
    required this.appModel,
  });

  @override
  State<TierMakerApp> createState() => _TierMakerAppState();
}

class _TierMakerAppState extends State<TierMakerApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.createRouter(widget.appModel);
  }

  @override
  Widget build(BuildContext context) {
    return AppModelProvider(
      notifier: widget.appModel,
      child: Builder(
        builder: (context) {
          final model = AppModelProvider.of(context);
          
          return ListenableBuilder(
            listenable: model,
            builder: (context, child) {
              return MaterialApp.router(
                title: 'Tier Maker',
                theme: AppTheme.ligthTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: _themeModeFromString(model.themeCode),
                locale: Locale(model.languageCode),
                routerConfig: _router,
              );
            },
          );
        },
      ),
    );
  }
}
```

### app_routes.dart

Определяет константы маршрутов приложения для использования в навигации через `go_router`.

```dart
abstract class AppRoutes {
  static const String home = '/';
  static const String settings = '/settings';
  static const String auth = '/auth';
  static const String guestTracks = '/guest-tracks';
  static const String network = '/network';
  static const String nfc = '/nfc';
  static const String search = '/search';
  static const String favorites = '/favorites';
  static const String playlists = '/playlists';
  static const String playlistDetails = '/playlist-details';
  static const String storage = '/storage';
  static const String topCharts = '/top-charts';
  
  static const String homeName = 'home';
  static const String settingsName = 'settings';
  static const String authName = 'auth';
  static const String guestTracksName = 'guestTracks';
  static const String networkName = 'network';
  static const String nfcName = 'nfc';
  static const String searchName = 'search';
  static const String favoritesName = 'favorites';
  static const String playlistsName = 'playlists';
  static const String playlistDetailsName = 'playlistDetails';
  static const String storageName = 'storage';
  static const String topChartsName = 'topCharts';
}
```

### models/app_model.dart

Модель глобального состояния приложения. Управляет темой (светлая/темная), языком интерфейса, состоянием авторизации пользователя (гость/авторизован), данными пользователя (email, nickname) и токенами доступа. Реализует `ChangeNotifier` для уведомления виджетов об изменениях состояния.

```dart
class AppModel extends ChangeNotifier {
  bool isLoading = true;
  String _appState = 'ltru000000'; // Формат: тема + язык + дополнительные данные
  bool _isGuest = true;
  String? _userEmail;
  String? _userNickname;

  bool get isDarkTheme => themeCode == 'dr';
  bool get isGuest => _isGuest;
  String? get userEmail => _userEmail;
  String? get userNickname => _userNickname;

  Future<void> init() async {
    isLoading = true;
    notifyListeners();
    await getCurrentTheme();
    await loadAuthState();
    isLoading = false;
    notifyListeners();
  }

  Future<void> setAuthData({
    required String email,
    required String username,
    required String accessToken,
    required String refreshToken,
    required int userId,
  }) async {
    _isGuest = false;
    _userEmail = email;
    _userNickname = username;
    await AppDatabase.setIsGuest(false);
    await AppDatabase.setUserEmail(email);
    await AppDatabase.setUserNickname(username);
    await AppDatabase.setAccessToken(accessToken);
    await AppDatabase.setRefreshToken(refreshToken);
    await AppDatabase.setUserId(userId);
    notifyListeners();
  }

  Future<void> clearAuthData() async {
    _isGuest = true;
    _userEmail = null;
    _userNickname = null;
    await AppDatabase.setIsGuest(true);
    await AppDatabase.setUserEmail(null);
    await AppDatabase.setUserNickname(null);
    await AppDatabase.setAccessToken(null);
    await AppDatabase.setRefreshToken(null);
    await AppDatabase.setUserId(null);
    notifyListeners();
  }

  Future<void> setTheme(String themeCode) async {
    if (themeCode.length == 2) {
      _appState = themeCode + _appState.substring(2);
      await AppDatabase.setAppTheme(_appState);
      notifyListeners();
    }
  }
}
```

### state/app_model_provider.dart

Провайдер для доступа к `AppModel` через контекст приложения. Использует `InheritedWidget` для предоставления модели всем дочерним виджетам.

```dart
class AppModelProvider extends InheritedNotifier<AppModel> {
  const AppModelProvider({
    super.key,
    required super.notifier,
    required super.child,
  });

  static AppModel of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<AppModelProvider>();
    if (provider == null) {
      throw Exception('AppModelProvider not found in context');
    }
    return provider.notifier!;
  }
}
```

## core

Центральный модуль приложения, содержащий общие компоненты, используемые во всех модулях: API клиенты, база данных, навигация, модели данных, репозитории и сервисы.

### app_database/app_database.dart

Класс для работы с локальным хранилищем приложения на базе Hive. Хранит состояние приложения (тема, язык), данные пользователя (email, nickname, токены), настройки API (базовый URL сервера). Все данные сохраняются в одном Hive box с ключами для доступа к различным значениям.

```dart
class AppDatabase {
  static const String _boxName = 'appBox';
  static const String _themeKey = 'appState';
  static const String _isGuestKey = 'isGuest';
  static const String _userEmailKey = 'userEmail';
  static const String _accessTokenKey = 'accessToken';
  static const String _apiBaseUrlKey = 'apiBaseUrl';
  static Box<String>? _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    await _ensureBox();
  }

  static Future<String> getAppTheme() async {
    final box = await _ensureBox();
    return box.get(_themeKey, defaultValue: 'ltru000000') ?? 'ltru000000';
  }

  static Future<void> setAppTheme(String appState) async {
    final box = await _ensureBox();
    await box.put(_themeKey, appState);
  }

  static Future<bool> getIsGuest() async {
    final box = await _ensureBox();
    final value = box.get(_isGuestKey, defaultValue: 'true');
    return value == 'true';
  }

  static Future<String?> getAccessToken() async {
    final box = await _ensureBox();
    return box.get(_accessTokenKey);
  }

  static Future<void> setAccessToken(String? token) async {
    final box = await _ensureBox();
    if (token != null) {
      await box.put(_accessTokenKey, token);
    } else {
      await box.delete(_accessTokenKey);
    }
  }

  static Future<String?> getApiBaseUrl() async {
    final box = await _ensureBox();
    return box.get(_apiBaseUrlKey);
  }

  static Future<void> setApiBaseUrl(String? url) async {
    final box = await _ensureBox();
    if (url != null && url.isNotEmpty) {
      final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      await box.put(_apiBaseUrlKey, cleanUrl);
    } else {
      await box.delete(_apiBaseUrlKey);
    }
  }
}
```

### api

API клиенты для взаимодействия с сервером и внешними сервисами.

#### auth_api.dart

Клиент для работы с API аутентификации. Реализует методы регистрации (`register`), входа (`login`), обновления токенов (`refreshToken`) и получения профиля пользователя (`getProfile`). Автоматически добавляет JWT токены в заголовки запросов и обрабатывает ошибки аутентификации.

```dart
class AuthApi {
  static Future<String> getBaseUrl() async {
    final savedUrl = await AppDatabase.getApiBaseUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      return savedUrl;
    }
    return EnvConfig.getApiBaseUrl();
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final baseUrl = await getBaseUrl();
    final url = '$baseUrl/auth/register';

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'email': email,
        'password': password,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 201) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'error': 'Ошибка регистрации'};
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final baseUrl = await getBaseUrl();
    final url = '$baseUrl/auth/login';

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'error': 'Неверные учетные данные'};
    }
  }
}
```

#### tracks_api.dart

Клиент для работы с API треков. Реализует загрузку треков на сервер (`uploadTrack`), получение списка треков пользователя (`getUserTracks`), получение информации о конкретном треке (`getTrack`) и удаление треков (`deleteTrack`). Поддерживает загрузку файлов через `multipart/form-data`.

```dart
class TracksApi {
  static Future<Map<String, String>> _getHeaders() async {
    final token = await getAccessToken();
    final headers = <String, String>{};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> uploadTrack({
    required File file,
    required String title,
    String? artist,
    String? album,
    int? duration,
  }) async {
    final baseUrl = await getBaseUrl();
    final url = '$baseUrl/tracks';
    final headers = await _getHeaders();

    var request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers.addAll(headers);
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    request.fields['title'] = title;
    if (artist != null) request.fields['artist'] = artist;
    if (album != null) request.fields['album'] = album;
    if (duration != null) request.fields['duration'] = duration.toString();

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 201) {
      return {'success': true, 'data': json.decode(responseBody)};
    } else {
      return {'success': false, 'error': 'Ошибка загрузки трека'};
    }
  }

  static Future<Map<String, dynamic>> getUserTracks() async {
    final baseUrl = await getBaseUrl();
    final url = '$baseUrl/tracks';
    final headers = await _getHeaders();

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'error': 'Ошибка получения треков'};
    }
  }
}
```

#### sync_api.dart

Клиент для синхронизации данных с сервером. Реализует получение данных пользователя (`getUserData`), загрузку плейлистов (`uploadPlaylists`) и синхронизацию всех данных (`uploadData`).

```dart
class SyncApi {
  static Future<Map<String, String>> _getHeaders() async {
    final token = await getAccessToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> downloadData() async {
    final baseUrl = await getBaseUrl();
    final url = '$baseUrl/sync/data';
    final headers = await _getHeaders();

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'error': 'Ошибка загрузки данных'};
    }
  }

  static Future<Map<String, dynamic>> uploadPlaylists(
    List<PlaylistDto> playlists,
  ) async {
    final baseUrl = await getBaseUrl();
    final url = '$baseUrl/sync/playlists';
    final headers = await _getHeaders();

    final body = playlists.map((p) => p.toJson()).toList();

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: json.encode(body),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'error': 'Ошибка отправки плейлистов'};
    }
  }
}
```

#### itunes_api.dart

Клиент для работы с iTunes Search API. Реализует поиск музыки по запросу пользователя. Возвращает результаты поиска с информацией о треках, исполнителях, альбомах и превью обложек.

```dart
class ITunesApi {
  static const String baseUrl = 'https://itunes.apple.com';

  static Future<List<Track>> searchTracks({
    required String query,
    int limit = 50,
  }) async {
    final encodedQuery = Uri.encodeComponent(query);
    final url = '$baseUrl/search?term=$encodedQuery&media=music&entity=song&limit=$limit';

    final response = await http.get(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      final results = jsonData['results'] as List<dynamic>? ?? [];

      final tracks = results
          .map((json) => Track.fromJson(json as Map<String, dynamic>))
          .toList();

      return tracks;
    } else {
      throw Exception('Ошибка поиска треков: ${response.statusCode}');
    }
  }
}
```

#### guest_tracks_api.dart

Клиент для работы с гостевой сессией (если реализовано на сервере). Позволяет получать треки без авторизации.

```dart
class GuestTracksApi {
  static Future<String> getBaseUrl() async {
    final savedUrl = await AppDatabase.getApiBaseUrl();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      return savedUrl;
    }
    return EnvConfig.getApiBaseUrl();
  }

  static Future<Map<String, dynamic>> getGuestTracks() async {
    try {
      final baseUrl = await getBaseUrl();
      final url = '$baseUrl/guest/tracks';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'error': 'Ошибка получения треков'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
```

#### backend_connection_test.dart

Утилита для проверки подключения к серверу. Используется для валидации URL сервера в настройках приложения.

```dart
class BackendConnectionTest {
  static Future<bool> testConnection(String url) async {
    try {
      final testUrl = url.endsWith('/') ? '${url}health' : '$url/health';
      final response = await http.get(
        Uri.parse(testUrl),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
```

### config/env_config.dart

Конфигурация приложения из переменных окружения. Загружает настройки из `.env` файла, включая базовый URL API по умолчанию.

```dart
class EnvConfig {
  static String? _apiBaseUrl;

  static String getApiBaseUrl() {
    if (_apiBaseUrl != null) return _apiBaseUrl!;
    
    try {
      final url = dotenv.env['API_BASE_URL'];
      if (url != null && url.isNotEmpty) {
        _apiBaseUrl = url;
        return url;
      }
    } catch (e) {
      debugPrint('[EnvConfig] Ошибка чтения API_BASE_URL из .env: $e');
    }

    // Fallback значение, если .env не загружен или переменная не задана
    const fallbackUrl = 'http://localhost:5050';
    _apiBaseUrl = fallbackUrl;
    return fallbackUrl;
  }

  static void setApiBaseUrl(String url) {
    _apiBaseUrl = url;
  }

  static void clearCache() {
    _apiBaseUrl = null;
  }
}
```

### navigation/app_router.dart

Конфигурация навигации приложения через `go_router`. Определяет все маршруты приложения, правила редиректа для авторизованных и гостевых пользователей, и связывает пути с соответствующими экранами.

```dart
class AppRouter {
  static GoRouter createRouter(AppModel appModel) {
    return GoRouter(
      initialLocation: AppRoutes.home,
      refreshListenable: appModel,
      redirect: (context, state) {
        final model = AppModelProvider.of(context);
        final currentPath = state.uri.path;
        final isAuth = currentPath == AppRoutes.auth;
        
        final guestAllowedPaths = [
          AppRoutes.home,
          AppRoutes.guestTracks,
          AppRoutes.network,
          AppRoutes.nfc,
          AppRoutes.auth,
          AppRoutes.settings,
        ];
        
        if (model.isGuest) {
          if (guestAllowedPaths.contains(currentPath)) {
            return null;
          } else {
            return AppRoutes.home;
          }
        }
        
        if (!model.isGuest && isAuth) {
          return AppRoutes.home;
        }
        
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.home,
          name: AppRoutes.homeName,
          builder: (context, state) => const MainScreen(),
        ),
        GoRoute(
          path: AppRoutes.auth,
          name: AppRoutes.authName,
          builder: (context, state) => const AuthScreen(),
        ),
        GoRoute(
          path: AppRoutes.playlists,
          name: AppRoutes.playlistsName,
          builder: (context, state) => const PlaylistsScreen(),
        ),
        GoRoute(
          path: '${AppRoutes.playlistDetails}/:id',
          name: AppRoutes.playlistDetailsName,
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return PlaylistDetailsScreen(playlistId: id);
          },
        ),
        // ... другие маршруты
      ],
    );
  }
}
```

### models

Модели данных для работы с плейлистами и треками в приложении.

#### track.dart

Модель трека из iTunes API. Содержит информацию о треке: ID, название, исполнитель, длительность, обложка, URL превью, статус избранного и ID плейлиста. Реализует методы `fromJson` и `toJson` для сериализации.

```dart
class Track {
  final int id;
  final String trackName;
  final String artistName;
  final String trackTime;
  final String? image;
  final String? previewUrl;
  bool favorite;
  int playlistId;

  factory Track.fromJson(Map<String, dynamic> json) {
    final trackTimeMillis = json['trackTimeMillis'] as int? ?? 0;
    final minutes = trackTimeMillis ~/ 60000;
    final seconds = (trackTimeMillis % 60000) ~/ 1000;
    final trackTime = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Track(
      id: json['trackId'] as int,
      trackName: json['trackName'] as String? ?? '',
      artistName: json['artistName'] as String? ?? '',
      trackTime: trackTime,
      image: json['artworkUrl100'] as String?,
      previewUrl: json['previewUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trackName': trackName,
      'artistName': artistName,
      'trackTime': trackTime,
      'image': image,
      'previewUrl': previewUrl,
      'favorite': favorite,
      'playlistId': playlistId,
    };
  }

  String get highQualityImage {
    if (image == null) return '';
    return image!.replaceAll('100x100bb', '600x600bb');
  }
}
```

#### playlist.dart

Модель плейлиста. Содержит ID, название, описание, URI обложки и список треков. Реализует методы `fromJson` и `toJson` для сериализации.

```dart
class Playlist {
  final int id;
  final String name;
  final String description;
  final String? coverImageUri;
  final List<Track> tracks;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'coverImageUri': coverImageUri,
      'tracks': tracks.map((t) => t.toJson()).toList(),
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      coverImageUri: json['coverImageUri'] as String?,
      tracks: (json['tracks'] as List<dynamic>?)
              ?.map((t) => Track.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
```

### repositories

Репозитории для работы с локальными данными через Hive.

#### playlists_repository.dart

Репозиторий для работы с плейлистами в локальном хранилище. Хранит плейлисты в формате JSON в Hive box. Реализует операции создания, чтения, обновления и удаления плейлистов, а также добавления и удаления треков из плейлистов.

```dart
class PlaylistsRepository {
  static const String _playlistsKey = 'playlists';
  static Box<String>? _box;
  static int _nextId = 1;

  static Future<List<Playlist>> getAllPlaylists() async {
    final box = await _ensureBox();
    final playlistsJson = box.get(_playlistsKey);
    if (playlistsJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(playlistsJson) as List<dynamic>;
      return jsonList
          .map((json) => Playlist.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<Playlist?> getPlaylistById(int id) async {
    final playlists = await getAllPlaylists();
    try {
      return playlists.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  static Future<Playlist> createPlaylist({
    required String name,
    String description = '',
    String? coverImageUri,
  }) async {
    final playlist = Playlist(
      id: _nextId++,
      name: name,
      description: description,
      coverImageUri: coverImageUri,
      tracks: [],
    );

    final playlists = await getAllPlaylists();
    playlists.add(playlist);
    await _savePlaylists(playlists);

    return playlist;
  }

  static Future<void> updatePlaylist(Playlist playlist) async {
    final playlists = await getAllPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlist.id);
    if (index != -1) {
      playlists[index] = playlist;
      await _savePlaylists(playlists);
    }
  }

  static Future<void> addTrackToPlaylist(int playlistId, Track track) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null) return;

    if (playlist.tracks.any((t) => t.id == track.id)) return;

    final updatedTracks = List<Track>.from(playlist.tracks);
    updatedTracks.add(track);

    final updatedPlaylist = Playlist(
      id: playlist.id,
      name: playlist.name,
      description: playlist.description,
      coverImageUri: playlist.coverImageUri,
      tracks: updatedTracks,
    );

    await updatePlaylist(updatedPlaylist);
  }

  static Future<void> _savePlaylists(List<Playlist> playlists) async {
    final box = await _ensureBox();
    final jsonList = playlists.map((p) => p.toJson()).toList();
    await box.put(_playlistsKey, json.encode(jsonList));
  }
}
```

#### tracks_repository.dart

Репозиторий для работы с избранными треками и историей поиска. Хранит список избранных треков и историю поисковых запросов в Hive box. Реализует операции добавления/удаления из избранного и управления историей поиска.

```dart
class TracksRepository {
  static const String _favoritesKey = 'favorites';
  static const String _searchHistoryKey = 'searchHistory';
  static Box<String>? _box;

  static Future<List<Track>> getFavorites() async {
    final box = await _ensureBox();
    final favoritesJson = box.get(_favoritesKey);
    if (favoritesJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(favoritesJson) as List<dynamic>;
      return jsonList
          .map((json) => Track.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> addToFavorites(Track track) async {
    final favorites = await getFavorites();
    if (favorites.any((t) => t.id == track.id)) return;

    final updatedTrack = Track(
      id: track.id,
      trackName: track.trackName,
      artistName: track.artistName,
      trackTime: track.trackTime,
      image: track.image,
      previewUrl: track.previewUrl,
      favorite: true,
      playlistId: track.playlistId,
    );

    favorites.add(updatedTrack);
    await _saveFavorites(favorites);
  }

  static Future<void> toggleFavorite(Track track) async {
    final favorites = await getFavorites();
    if (favorites.any((t) => t.id == track.id)) {
      await removeFromFavorites(track);
    } else {
      await addToFavorites(track);
    }
  }

  static Future<void> addToSearchHistory(String query) async {
    if (query.trim().isEmpty) return;

    final history = await getSearchHistory();
    history.remove(query.trim());
    history.insert(0, query.trim());

    // Ограничиваем историю 10 записями
    if (history.length > 10) {
      history.removeRange(10, history.length);
    }

    final box = await _ensureBox();
    await box.put(_searchHistoryKey, json.encode(history));
  }

  static Future<void> _saveFavorites(List<Track> favorites) async {
    final box = await _ensureBox();
    final jsonList = favorites.map((t) => t.toJson()).toList();
    await box.put(_favoritesKey, json.encode(jsonList));
  }
}
```

### services

Сервисы для выполнения фоновых операций.

#### download_service.dart

Сервис для загрузки треков с сервера на устройство. Реализует загрузку файлов с отображением прогресса и сохранением в локальное хранилище устройства.

```dart
class DownloadService {
  static Future<Map<String, dynamic>> downloadTracks() async {
    try {
      final result = await TracksApi.getUserTracks();
      if (result['success'] != true) {
        return result;
      }

      final data = result['data'] as Map<String, dynamic>?;
      final tracksJson = data?['tracks'] as List<dynamic>?;

      if (tracksJson == null || tracksJson.isEmpty) {
        return {'success': true, 'message': 'Нет треков на сервере'};
      }

      // Преобразуем треки в TrackDto
      final tracks = <TrackDto>[];
      for (final json in tracksJson) {
        final trackData = json as Map<String, dynamic>;
        final track = TrackDto(
          trackId: trackData['id'] as int,
          trackName: trackData['title'] as String?,
          artistName: trackData['artist'] as String?,
          trackTimeMillis: trackData['duration'] != null
              ? (trackData['duration'] as int) * 1000
              : null,
          previewUrl: trackData['file_url'] as String?,
        );
        tracks.add(track);
      }

      // Скачиваем файлы треков в локальное хранилище
      for (final track in tracks) {
        if (track.previewUrl != null && track.previewUrl!.isNotEmpty) {
          await _downloadTrackFile(track);
        }
      }

      // Сохраняем треки в избранное
      await _localStorage.saveFavorites(tracks);

      return {
        'success': true,
        'message': 'Загружено треков: ${tracks.length}',
        'count': tracks.length,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<void> _downloadTrackFile(TrackDto track) async {
    // Получаем директорию для сохранения
    final directory = await _getDownloadDirectory();
    final fileName = '${track.artistName} - ${track.trackName}.m4a';
    final filePath = '${directory.path}/$fileName';

    // Скачиваем файл
    final response = await http.get(
      Uri.parse(track.previewUrl!),
      headers: {'Authorization': 'Bearer ${await TracksApi.getAccessToken()}'},
    );

    if (response.statusCode == 200) {
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
    }
  }
}
```

#### upload_service.dart

Сервис для загрузки треков с устройства на сервер. Реализует загрузку файлов через multipart/form-data с отображением прогресса и обработкой ошибок.

```dart
class UploadService {
  static Future<Map<String, dynamic>> uploadDownloadedTrack(
    DownloadedTrack track,
  ) async {
    try {
      final file = File(track.filePath);
      if (!await file.exists()) {
        return {'success': false, 'error': 'Файл не найден'};
      }

      final duration = track.durationMillis != null 
          ? (track.durationMillis! / 1000).round() 
          : null;

      final result = await TracksApi.uploadTrack(
        file: file,
        title: track.trackName,
        artist: track.artistName,
        duration: duration,
      );

      return result;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> uploadAllDownloadedTracks(
    List<DownloadedTrack> tracks,
    Function(int current, int total)? onProgress,
  ) async {
    int successCount = 0;
    int failCount = 0;

    for (int i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      onProgress?.call(i + 1, tracks.length);

      final result = await uploadDownloadedTrack(track);
      if (result['success'] == true) {
        successCount++;
      } else {
        failCount++;
      }
    }

    return {
      'success': failCount == 0,
      'successCount': successCount,
      'failCount': failCount,
    };
  }

  static Future<Map<String, dynamic>> uploadPlaylists() async {
    try {
      final playlists = await _localStorage.getPlaylists();
      if (playlists.isEmpty) {
        return {'success': true, 'message': 'Нет плейлистов для загрузки'};
      }

      final result = await SyncApi.uploadPlaylists(playlists);
      return result;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
```

### global_widgets/panel_header.dart

Переиспользуемый виджет заголовка экрана. Отображает название экрана и кнопку "Назад" для навигации. Используется на всех экранах приложения для единообразия интерфейса.

```dart
class PanelHeader extends StatelessWidget {
  final String name;
  final bool showBackButton;
  final VoidCallback? onBackClick;
  final Color? textColor;

  const PanelHeader({
    super.key,
    required this.name,
    this.showBackButton = false,
    this.onBackClick,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTextColor = textColor ?? theme.colorScheme.onBackground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        spacing: 40,
        children: [
          if (showBackButton)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBackClick ?? () => context.pop(),
              color: effectiveTextColor,
            ),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.titleLarge?.copyWith(
                color: effectiveTextColor,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

## auth

Модуль аутентификации пользователей.

### presentation/screens/auth_screen.dart

Экран авторизации и регистрации. Содержит форму для входа и регистрации с переключателем между режимами. Валидирует ввод данных, отправляет запросы на сервер через `AuthApi` и обрабатывает ответы. При успешной авторизации сохраняет токены и данные пользователя в `AppDatabase` и переходит на главный экран.

## home

Модуль главного экрана и связанных компонентов для работы с треками из сети и локального хранилища.

### presentation/screens

Экраны для отображения главного меню, списка треков из сети, детальной информации о треках.

#### main_screen.dart

Главный экран приложения с меню навигации. Отображает список разделов приложения (Сеть, NFC, Хранилище, Плейлисты, Избранное, Топ-чарт, Настройки) и обрабатывает переходы на соответствующие экраны.

#### network_screen.dart

Экран для отображения треков, полученных из iTunes API. Показывает список найденных треков с возможностью просмотра детальной информации и добавления в избранное.

#### network_track_details_screen.dart

Экран детальной информации о треке из сети. Отображает полную информацию о треке, обложку, возможность воспроизведения превью и добавления в плейлисты.

#### universal_track_details_screen.dart

Универсальный экран детальной информации о треке, который может использоваться для отображения информации о треках из различных источников.

### presentation/widgets

Виджеты для отображения элементов списка треков.

#### network_track_item.dart

Виджет элемента списка треков из сети. Отображает название, исполнителя, обложку и кнопки действий для трека.

### domain

Бизнес-логика модуля home.

#### model

Модели данных для работы с загруженными треками и треками из сети.

#### repository

Интерфейсы и реализации репозиториев для работы с загруженными треками и треками из сети.

#### usecase

Use cases для бизнес-логики: получение загруженных треков, удаление треков, загрузка треков, поиск треков.

### presentation/providers

Провайдеры состояния для управления данными экранов модуля home.

### presentation/state

Модели состояния для экранов модуля home.

## playlists

Модуль управления плейлистами пользователя.

### presentation/screens

Экраны для работы с плейлистами.

#### playlists_screen.dart

Экран списка плейлистов пользователя. Отображает все плейлисты, загруженные из локального хранилища или синхронизированные с сервером. Позволяет открыть плейлист для просмотра деталей.

#### playlist_details_screen.dart

Экран детальной информации о плейлисте. Отображает название, описание, список треков в плейлисте с возможностью управления (добавление, удаление треков). Позволяет синхронизировать плейлист с сервером.

### presentation/widgets

Виджеты для отображения элементов плейлистов.

#### playlist_item.dart

Виджет элемента списка плейлистов. Отображает название плейлиста, количество треков, обложку (если есть) и обрабатывает нажатие для перехода к деталям плейлиста.

## search

Модуль поиска музыки через iTunes API.

### presentation/screens/search_screen.dart

Экран поиска музыки. Содержит поле ввода для поискового запроса, отображает результаты поиска в виде списка треков. Позволяет добавлять найденные треки в избранное или плейлисты.

### presentation/widgets/track_item.dart

Виджет элемента результата поиска. Отображает информацию о треке (название, исполнитель, обложка) и кнопки действий.

## favorites

Модуль управления избранными треками.

### presentation/screens/favorites_screen.dart

Экран избранных треков. Отображает список треков, добавленных в избранное через `TracksRepository`. Позволяет удалять треки из избранного и переходить к детальной информации о треке.

## storage

Модуль управления внутренним хранилищем устройства.

### presentation/screens/storage_screen.dart

Экран внутреннего хранилища устройства. Отображает список аудиофайлов, найденных в локальном хранилище устройства. Позволяет загружать треки на сервер, удалять файлы и просматривать детальную информацию о треках.

### presentation/widgets/downloaded_track_item.dart

Виджет элемента списка загруженных треков. Отображает информацию о файле и кнопки действий (загрузить на сервер, удалить).

## nfc

Модуль интеграции с NFC для воспроизведения треков по меткам.

### presentation/screens/nfc_screen.dart

Экран управления NFC. Отображает состояние NFC на устройстве, позволяет сканировать NFC метки и привязывать треки к меткам для автоматического воспроизведения.

## top_charts

Модуль отображения топ-чартов музыки.

### presentation/screens/top_charts_screen.dart

Экран топ-чартов. Отображает популярные треки, полученные через iTunes API или другие источники.

## settings

Модуль настроек приложения.

### presentation/screens/settings_screen.dart

Экран настроек приложения. Позволяет настраивать URL сервера API, переключать тему (светлая/темная), выбирать язык интерфейса, просматривать информацию о приложении и выполнять синхронизацию данных.

### domain/model/settings_model.dart

Модель состояния настроек приложения. Управляет настройками и их сохранением в `AppDatabase`.

### presentation/providers/settings_provider.dart

Провайдер для управления состоянием экрана настроек.

### presentation/widgets/setting_support_functions.dart

Вспомогательные функции для работы с настройками.

## guest_tracks

Модуль для работы с треками в гостевом режиме (если реализовано).

### presentation/screens/guest_tracks_screen.dart

Экран треков для гостевых пользователей. Отображает треки, доступные без авторизации.

## data

Модуль слоя данных в архитектуре Clean Architecture. Содержит реализации репозиториев и источников данных.

### datasources

Источники данных для получения информации из различных источников.

#### local/local_storage_datasource.dart

Источник данных для работы с локальным хранилищем устройства. Реализует поиск аудиофайлов в файловой системе устройства.

```dart
abstract class LocalStorageDataSource {
  Future<List<TrackDto>> getFavorites();
  Future<void> saveFavorites(List<TrackDto> tracks);
  Future<List<String>> getSearchHistory();
  Future<void> saveSearchHistory(List<String> history);
  Future<List<PlaylistDto>> getPlaylists();
  Future<void> savePlaylists(List<PlaylistDto> playlists);
}

class LocalStorageDataSourceImpl implements LocalStorageDataSource {
  static const String _boxName = 'appBox';
  static const String _favoritesKey = 'favorites';
  static const String _playlistsKey = 'playlists';
  static Box<String>? _box;

  @override
  Future<List<TrackDto>> getFavorites() async {
    final box = await _ensureBox();
    final favoritesJson = box.get(_favoritesKey);
    if (favoritesJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(favoritesJson) as List<dynamic>;
      return jsonList
          .map((json) => TrackDto.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> saveFavorites(List<TrackDto> tracks) async {
    final box = await _ensureBox();
    final jsonList = tracks.map((t) => t.toJson()).toList();
    await box.put(_favoritesKey, json.encode(jsonList));
  }

  @override
  Future<List<PlaylistDto>> getPlaylists() async {
    final box = await _ensureBox();
    final playlistsJson = box.get(_playlistsKey);
    if (playlistsJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(playlistsJson) as List<dynamic>;
      return jsonList
          .map((json) => PlaylistDto.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> savePlaylists(List<PlaylistDto> playlists) async {
    final box = await _ensureBox();
    final jsonList = playlists.map((p) => p.toJson()).toList();
    await box.put(_playlistsKey, json.encode(jsonList));
  }
}
```

#### remote/itunes_remote_datasource.dart

Источник данных для работы с iTunes API. Реализует запросы к iTunes Search API и преобразование ответов в модели данных приложения.

```dart
abstract class ITunesRemoteDataSource {
  Future<List<TrackDto>> searchTracks(String query, {int limit = 50});
}

class ITunesRemoteDataSourceImpl implements ITunesRemoteDataSource {
  static const String baseUrl = 'https://itunes.apple.com';

  @override
  Future<List<TrackDto>> searchTracks(String query, {int limit = 50}) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = '$baseUrl/search?term=$encodedQuery&media=music&entity=song&limit=$limit';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final results = jsonData['results'] as List<dynamic>? ?? [];

        final tracks = results
            .map((json) => TrackDto.fromJson(json as Map<String, dynamic>))
            .toList();

        return tracks;
      } else {
        throw Exception('Ошибка поиска треков: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
```

### models

DTO (Data Transfer Objects) для передачи данных между слоями.

#### track_dto.dart

DTO для передачи данных о треке между слоями приложения.

```dart
class TrackDto {
  final int trackId;
  final String? trackName;
  final String? artistName;
  final int? trackTimeMillis;
  final String? artworkUrl100;
  final String? previewUrl;

  TrackDto({
    required this.trackId,
    this.trackName,
    this.artistName,
    this.trackTimeMillis,
    this.artworkUrl100,
    this.previewUrl,
  });

  factory TrackDto.fromJson(Map<String, dynamic> json) {
    return TrackDto(
      trackId: json['trackId'] as int,
      trackName: json['trackName'] as String?,
      artistName: json['artistName'] as String?,
      trackTimeMillis: json['trackTimeMillis'] as int?,
      artworkUrl100: json['artworkUrl100'] as String?,
      previewUrl: json['previewUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trackId': trackId,
      'trackName': trackName,
      'artistName': artistName,
      'trackTimeMillis': trackTimeMillis,
      'artworkUrl100': artworkUrl100,
      'previewUrl': previewUrl,
    };
  }

  /// Преобразование в доменную сущность
  TrackEntity toEntity() {
    final minutes = (trackTimeMillis ?? 0) ~/ 60000;
    final seconds = ((trackTimeMillis ?? 0) % 60000) ~/ 1000;
    final trackTime = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return TrackEntity(
      id: trackId,
      trackName: trackName ?? '',
      artistName: artistName ?? '',
      trackTime: trackTime,
      image: artworkUrl100,
      previewUrl: previewUrl,
    );
  }

  static TrackDto fromEntity(TrackEntity entity) {
    final timeParts = entity.trackTime.split(':');
    final minutes = int.tryParse(timeParts[0]) ?? 0;
    final seconds = int.tryParse(timeParts[1]) ?? 0;
    final trackTimeMillis = (minutes * 60 + seconds) * 1000;

    return TrackDto(
      trackId: entity.id,
      trackName: entity.trackName,
      artistName: entity.artistName,
      trackTimeMillis: trackTimeMillis,
      artworkUrl100: entity.image,
      previewUrl: entity.previewUrl,
    );
  }
}
```

#### playlist_dto.dart

DTO для передачи данных о плейлисте между слоями приложения.

```dart
class PlaylistDto {
  final int id;
  final String name;
  final String description;
  final String? coverImageUri;
  final List<TrackDto> tracks;

  PlaylistDto({
    required this.id,
    required this.name,
    this.description = '',
    this.coverImageUri,
    required this.tracks,
  });

  factory PlaylistDto.fromJson(Map<String, dynamic> json) {
    return PlaylistDto(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      coverImageUri: json['coverImageUri'] as String?,
      tracks: (json['tracks'] as List<dynamic>?)
              ?.map((t) => TrackDto.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'coverImageUri': coverImageUri,
      'tracks': tracks.map((t) => t.toJson()).toList(),
    };
  }

  PlaylistEntity toEntity() {
    return PlaylistEntity(
      id: id,
      name: name,
      description: description,
      coverImageUri: coverImageUri,
      tracks: tracks.map((t) => t.toEntity()).toList(),
    );
  }

  static PlaylistDto fromEntity(PlaylistEntity entity) {
    return PlaylistDto(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      coverImageUri: entity.coverImageUri,
      tracks: entity.tracks.map((t) => TrackDto.fromEntity(t)).toList(),
    );
  }
}
```

### repositories

Реализации репозиториев для работы с данными.

#### tracks_repository_impl.dart

Реализация репозитория для работы с треками. Объединяет работу с локальными и удаленными источниками данных.

```dart
class TracksRepositoryImpl implements TracksRepository {
  final ITunesRemoteDataSource remoteDataSource;
  final LocalStorageDataSource localDataSource;

  TracksRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<List<TrackEntity>> searchTracks(String query, {int limit = 50}) async {
    final dtos = await remoteDataSource.searchTracks(query, limit: limit);
    return dtos.map((dto) => dto.toEntity()).toList();
  }

  @override
  Future<List<TrackEntity>> getFavorites() async {
    final dtos = await localDataSource.getFavorites();
    return dtos.map((dto) => dto.toEntity()).toList();
  }

  @override
  Future<void> addToFavorites(TrackEntity track) async {
    final favorites = await getFavorites();
    if (favorites.any((t) => t.id == track.id)) return;

    final updatedTrack = track.copyWith(favorite: true);
    favorites.add(updatedTrack);
    
    final dtos = favorites.map((t) => TrackDto.fromEntity(t)).toList();
    await localDataSource.saveFavorites(dtos);
  }

  @override
  Future<void> toggleFavorite(TrackEntity track) async {
    final favorites = await getFavorites();
    if (favorites.any((t) => t.id == track.id)) {
      await removeFromFavorites(track);
    } else {
      await addToFavorites(track);
    }
  }
}
```

#### playlists_repository_impl.dart

Реализация репозитория для работы с плейлистами. Объединяет работу с локальным хранилищем и синхронизацию с сервером.

```dart
class PlaylistsRepositoryImpl implements PlaylistsRepository {
  final LocalStorageDataSource localDataSource;
  int _nextId = 1;

  PlaylistsRepositoryImpl({
    required this.localDataSource,
  });

  @override
  Future<List<PlaylistEntity>> getAllPlaylists() async {
    final dtos = await localDataSource.getPlaylists();
    return dtos.map((dto) => dto.toEntity()).toList();
  }

  @override
  Future<PlaylistEntity> createPlaylist({
    required String name,
    String description = '',
    String? coverImageUri,
  }) async {
    final playlists = await getAllPlaylists();
    if (playlists.isNotEmpty) {
      _nextId = playlists.map((p) => p.id).reduce((a, b) => a > b ? a : b) + 1;
    }
    
    final playlist = PlaylistEntity(
      id: _nextId++,
      name: name,
      description: description,
      coverImageUri: coverImageUri,
      tracks: [],
    );

    playlists.add(playlist);
    final dtos = playlists.map((p) => PlaylistDto.fromEntity(p)).toList();
    await localDataSource.savePlaylists(dtos);

    return playlist;
  }

  @override
  Future<void> updatePlaylist(PlaylistEntity playlist) async {
    final playlists = await getAllPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlist.id);
    if (index != -1) {
      playlists[index] = playlist;
      final dtos = playlists.map((p) => PlaylistDto.fromEntity(p)).toList();
      await localDataSource.savePlaylists(dtos);
    }
  }

  @override
  Future<void> addTrackToPlaylist(int playlistId, TrackEntity track) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null) return;

    if (playlist.tracks.any((t) => t.id == track.id)) return;

    final updatedTracks = List<TrackEntity>.from(playlist.tracks);
    updatedTracks.add(track);

    final updatedPlaylist = playlist.copyWith(tracks: updatedTracks);
    await updatePlaylist(updatedPlaylist);
  }
}
```

## domain

Модуль слоя доменной логики в архитектуре Clean Architecture. Содержит бизнес-сущности, интерфейсы репозиториев и use cases.

### entities

Бизнес-сущности приложения.

#### track.dart

Доменная сущность трека. Представляет трек в бизнес-логике приложения.

```dart
class TrackEntity {
  final int id;
  final String trackName;
  final String artistName;
  final String trackTime;
  final String? image;
  final String? previewUrl;
  final bool favorite;
  final int playlistId;

  TrackEntity({
    required this.id,
    required this.trackName,
    required this.artistName,
    required this.trackTime,
    this.image,
    this.previewUrl,
    this.favorite = false,
    this.playlistId = 0,
  });

  TrackEntity copyWith({
    int? id,
    String? trackName,
    String? artistName,
    String? trackTime,
    String? image,
    String? previewUrl,
    bool? favorite,
    int? playlistId,
  }) {
    return TrackEntity(
      id: id ?? this.id,
      trackName: trackName ?? this.trackName,
      artistName: artistName ?? this.artistName,
      trackTime: trackTime ?? this.trackTime,
      image: image ?? this.image,
      previewUrl: previewUrl ?? this.previewUrl,
      favorite: favorite ?? this.favorite,
      playlistId: playlistId ?? this.playlistId,
    );
  }

  String get highQualityImage {
    if (image == null) return '';
    return image!.replaceAll('100x100bb', '600x600bb');
  }
}
```

#### playlist.dart

Доменная сущность плейлиста. Представляет плейлист в бизнес-логике приложения.

```dart
class PlaylistEntity {
  final int id;
  final String name;
  final String description;
  final String? coverImageUri;
  final List<TrackEntity> tracks;

  PlaylistEntity({
    required this.id,
    required this.name,
    this.description = '',
    this.coverImageUri,
    required this.tracks,
  });

  PlaylistEntity copyWith({
    int? id,
    String? name,
    String? description,
    String? coverImageUri,
    List<TrackEntity>? tracks,
  }) {
    return PlaylistEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverImageUri: coverImageUri ?? this.coverImageUri,
      tracks: tracks ?? this.tracks,
    );
  }
}
```

### repositories

Интерфейсы репозиториев для работы с данными. Определяют контракты для реализации в слое данных.

#### tracks_repository.dart

Интерфейс репозитория для работы с треками. Определяет методы для получения, создания, обновления и удаления треков.

```dart
abstract class TracksRepository {
  Future<List<TrackEntity>> searchTracks(String query, {int limit = 50});
  Future<List<TrackEntity>> getFavorites();
  Future<void> addToFavorites(TrackEntity track);
  Future<void> removeFromFavorites(TrackEntity track);
  Future<void> toggleFavorite(TrackEntity track);
  Future<bool> isFavorite(TrackEntity track);
  Future<List<String>> getSearchHistory();
  Future<void> addToSearchHistory(String query);
  Future<void> clearSearchHistory();
}
```

#### playlists_repository.dart

Интерфейс репозитория для работы с плейлистами. Определяет методы для работы с плейлистами и их синхронизацией.

```dart
abstract class PlaylistsRepository {
  Future<List<PlaylistEntity>> getAllPlaylists();
  Future<PlaylistEntity?> getPlaylistById(int id);
  Future<PlaylistEntity> createPlaylist({
    required String name,
    String description = '',
    String? coverImageUri,
  });
  Future<void> updatePlaylist(PlaylistEntity playlist);
  Future<void> deletePlaylist(int id);
  Future<void> addTrackToPlaylist(int playlistId, TrackEntity track);
  Future<void> removeTrackFromPlaylist(int playlistId, TrackEntity track);
}
```

### usecases

Use cases для бизнес-логики приложения.

#### search_tracks_usecase.dart

Use case для поиска треков через iTunes API. Инкапсулирует логику поиска и преобразования результатов.

```dart
class SearchTracksUseCase {
  final TracksRepository repository;

  SearchTracksUseCase(this.repository);

  Future<List<TrackEntity>> execute(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) {
      return [];
    }

    // Сохраняем запрос в историю
    await repository.addToSearchHistory(query);

    // Выполняем поиск
    final tracks = await repository.searchTracks(query, limit: limit);

    // Проверяем статус избранного для каждого трека
    final tracksWithFavorite = await Future.wait(
      tracks.map((track) async {
        final isFavorite = await repository.isFavorite(track);
        return track.copyWith(favorite: isFavorite);
      }),
    );

    return tracksWithFavorite;
  }
}
```

#### toggle_favorite_usecase.dart

Use case для добавления/удаления треков из избранного. Инкапсулирует логику работы с избранным.

```dart
class ToggleFavoriteUseCase {
  final TracksRepository repository;

  ToggleFavoriteUseCase(this.repository);

  Future<void> execute(TrackEntity track) async {
    await repository.toggleFavorite(track);
  }
}
```

#### get_favorites_usecase.dart

Use case для получения списка избранных треков. Инкапсулирует логику получения избранного из локального хранилища.

```dart
class GetFavoritesUseCase {
  final TracksRepository repository;

  GetFavoritesUseCase(this.repository);

  Future<List<TrackEntity>> execute() async {
    return await repository.getFavorites();
  }
}
```

#### create_playlist_usecase.dart

Use case для создания нового плейлиста. Инкапсулирует логику создания плейлиста с валидацией данных.

```dart
class CreatePlaylistUseCase {
  final PlaylistsRepository repository;

  CreatePlaylistUseCase(this.repository);

  Future<PlaylistEntity> execute({
    required String name,
    String description = '',
    String? coverImageUri,
  }) async {
    if (name.trim().isEmpty) {
      throw Exception('Название плейлиста не может быть пустым');
    }

    return await repository.createPlaylist(
      name: name.trim(),
      description: description.trim(),
      coverImageUri: coverImageUri,
    );
  }
}
```

#### add_track_to_playlist_usecase.dart

Use case для добавления трека в плейлист. Инкапсулирует логику добавления трека с проверкой дубликатов.

```dart
class AddTrackToPlaylistUseCase {
  final PlaylistsRepository repository;

  AddTrackToPlaylistUseCase(this.repository);

  Future<void> execute(int playlistId, TrackEntity track) async {
    final playlist = await repository.getPlaylistById(playlistId);
    if (playlist == null) {
      throw Exception('Плейлист не найден');
    }

    // Проверяем, не добавлен ли уже трек
    if (playlist.tracks.any((t) => t.id == track.id)) {
      throw Exception('Трек уже добавлен в плейлист');
    }

    await repository.addTrackToPlaylist(playlistId, track);
  }
}
```

## di

Модуль dependency injection для управления зависимостями приложения.

### dependency_injection.dart

Конфигурация dependency injection. Определяет провайдеры для всех зависимостей приложения, включая репозитории, use cases, API клиенты и другие сервисы. Используется для обеспечения слабой связанности компонентов и упрощения тестирования.

```dart
class DependencyInjection {
  // Data Sources
  static final LocalStorageDataSource _localDataSource =
      LocalStorageDataSourceImpl();
  static final ITunesRemoteDataSource _remoteDataSource =
      ITunesRemoteDataSourceImpl();

  // Repositories
  static final TracksRepository _tracksRepository = TracksRepositoryImpl(
    remoteDataSource: _remoteDataSource,
    localDataSource: _localDataSource,
  );

  static final PlaylistsRepository _playlistsRepository =
      PlaylistsRepositoryImpl(
    localDataSource: _localDataSource,
  );

  // Use Cases
  static final SearchTracksUseCase searchTracksUseCase =
      SearchTracksUseCase(_tracksRepository);
  static final ToggleFavoriteUseCase toggleFavoriteUseCase =
      ToggleFavoriteUseCase(_tracksRepository);
  static final GetFavoritesUseCase getFavoritesUseCase =
      GetFavoritesUseCase(_tracksRepository);
  static final CreatePlaylistUseCase createPlaylistUseCase =
      CreatePlaylistUseCase(_playlistsRepository);
  static final AddTrackToPlaylistUseCase addTrackToPlaylistUseCase =
      AddTrackToPlaylistUseCase(_playlistsRepository);

  // Repositories для прямого доступа
  static TracksRepository get tracksRepository => _tracksRepository;
  static PlaylistsRepository get playlistsRepository => _playlistsRepository;
}
```

## theme

Модуль темизации приложения.

### theme.dart

Конфигурация тем приложения (светлая и темная). Определяет цветовую схему, стили текста, размеры и другие параметры визуального оформления на основе Material Design.

```dart
abstract class AppTheme {
  // Основные цвета
  static const Color primaryColor = Color(0xFFFF0000);
  static const Color primaryColorDark = Color(0xFFBF3030);
  static const Color secondaryColorA = Color(0xFFFF7400);
  static const Color secondaryColorB = Color(0xFFCD0074);

  // Цвета для светлой темы
  static const Color lightPrimary = Colors.black;
  static const Color lightOnPrimary = Colors.black;
  static const Color lightSurface = Colors.white;
  static const Color lightOnSurface = Colors.black;

  // Цвета для темной темы
  static const Color darkPrimary = Colors.white;
  static const Color darkOnPrimary = Colors.white;
  static const Color darkSurface = Color(0xFF1A0000);
  static const Color darkOnSurface = Colors.white;

  // Светлая тема
  static ThemeData get ligthTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: lightPrimary,
        onPrimary: lightOnPrimary,
        surface: lightSurface,
        onSurface: lightOnSurface,
        secondary: secondaryColorA,
      ),
      scaffoldBackgroundColor: primaryColor,
    );
  }

  // Темная тема
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: darkPrimary,
        onPrimary: darkOnPrimary,
        surface: darkSurface,
        onSurface: darkOnSurface,
        secondary: secondaryColorBLighter,
      ),
      scaffoldBackgroundColor: primaryColorDarker,
    );
  }
}
```

## main.dart

Точка входа приложения. Инициализирует Flutter приложение, загружает переменные окружения, инициализирует базу данных, настраивает глобальное состояние и запускает приложение.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:RandomTierList/app/my_app.dart';
import 'package:RandomTierList/app/models/app_model.dart';
import 'package:RandomTierList/core/app_database/app_database.dart';
import 'package:RandomTierList/core/api/guest_tracks_api.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('[main] Предупреждение: не удалось загрузить .env файл: $e');
  }

  await AppDatabase.init();

  await GuestTracksApi.getBaseUrl();

  final appModel = AppModel();
  await appModel.init();

  runApp(TierMakerApp(appModel: appModel));
}
```

