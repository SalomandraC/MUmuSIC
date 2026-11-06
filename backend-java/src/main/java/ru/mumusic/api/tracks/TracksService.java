package ru.mumusic.api.tracks;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import ru.mumusic.api.common.JsonConfig;
import ru.mumusic.api.common.UriEncoding;
import ru.mumusic.api.config.AppConfig;
import ru.mumusic.api.security.TokenService;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class TracksService {

    private static final Logger log = LoggerFactory.getLogger(TracksService.class);

    private final TrackRepository tracks;
    private final TokenService tokens;
    private final AppConfig config;

    public TracksService(TrackRepository tracks, TokenService tokens, AppConfig config) {
        this.tracks = tracks;
        this.tokens = tokens;
        this.config = config;
    }

    public Map<String, Object> create(long userId, TrackRepository.NewTrack data, String relativePath,
                                      String format, long size) {
        return toResponse(tracks.create(userId, data, relativePath, format, size));
    }

    public List<Map<String, Object>> userTracks(long userId) {
        return tracks.findByUserId(userId).stream().map(this::toResponse).toList();
    }

    /** null — нет трека, это метаданные плейлиста или чужой приватный трек (выглядит как несуществующий) */
    public Map<String, Object> byId(long id, long userId) {
        return tracks.findById(id)
                .filter(t -> !"metadata".equals(t.fileFormat()))
                .filter(t -> t.userId() == userId || t.isPublic())
                .map(this::toResponse)
                .orElse(null);
    }

    public boolean delete(long id, long userId) {
        Track track = tracks.findById(id).orElse(null);
        if (track == null || track.userId() != userId) return false;

        boolean deleted = tracks.delete(id, userId);
        if (deleted && track.filePath() != null) {
            try {
                Files.deleteIfExists(config.storageRoot().resolve(track.filePath().replace('\\', '/')));
            } catch (IOException | RuntimeException e) {
                log.warn("Не удалось удалить файл трека {}: {}", id, e.getMessage());
            }
        }
        return deleted;
    }

    /**
     * /storage/users/... отдаётся только владельцу. Приложение играет и скачивает трек
     * по file_url без заголовка Authorization, поэтому ссылка подписана токеном
     * на этот конкретный файл (срок жизни MEDIA_TOKEN_TTL).
     */
    Map<String, Object> toResponse(Track t) {
        String normalizedPath = t.filePath().replace('\\', '/');
        String mediaToken = tokens.generateMediaToken(t.userId(), normalizedPath);
        String encoded = Arrays.stream(normalizedPath.split("/", -1))
                .map(UriEncoding::encodeComponent)
                .collect(Collectors.joining("/"));

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("id", t.id());
        out.put("title", t.title());
        out.put("artist", t.artist());
        out.put("album", t.album());
        out.put("duration", t.duration());
        out.put("file_path", t.filePath());
        out.put("file_url", "/storage/" + encoded + "?token=" + mediaToken);
        out.put("file_format", t.fileFormat());
        out.put("file_size", t.fileSize());
        out.put("notes", t.notes());
        out.put("is_public", t.isPublic());
        out.put("created_at", JsonConfig.iso(t.createdAt()));
        return out;
    }
}
