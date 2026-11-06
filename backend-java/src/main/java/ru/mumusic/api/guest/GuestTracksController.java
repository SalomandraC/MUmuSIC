package ru.mumusic.api.guest;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import ru.mumusic.api.common.BaseUrl;
import ru.mumusic.api.common.Db;
import ru.mumusic.api.common.HttpError;
import ru.mumusic.api.common.JsNumbers;
import ru.mumusic.api.common.JsStrings;
import ru.mumusic.api.common.JsonConfig;
import ru.mumusic.api.config.AppConfig;
import ru.mumusic.api.storage.MimeTypes;
import ru.mumusic.api.storage.RangeStreaming;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.stream.Stream;

/**
 * Гостевые треки, топ и NFC: /guest-tracks, /guest-tracks/{id}/stream,
 * /guest-tracks/by-title/stream, /guest-tracks/nfc/stream (порт guest.routes.ts).
 */
@RestController
@RequestMapping("/guest-tracks")
@Tag(name = "Guest", description = "Треки для гостей")
public class GuestTracksController {

    private static final Logger log = LoggerFactory.getLogger(GuestTracksController.class);
    private static final List<String> AUDIO_EXTENSIONS = List.of(".mp3", ".wav", ".m4a", ".ogg");

    private final JdbcTemplate jdbc;
    private final AppConfig config;

    public GuestTracksController(JdbcTemplate jdbc, AppConfig config) {
        this.jdbc = jdbc;
        this.config = config;
    }

    @Operation(summary = "Список активных гостевых треков")
    @GetMapping({"", "/"})
    public List<Map<String, Object>> list(HttpServletRequest req) {
        String baseUrl = BaseUrl.of(req);
        List<Map<String, Object>> rows = jdbc.query("""
                SELECT id, title, artist, file_path, file_format, duration, file_size, is_active, play_count, created_at
                FROM guest_tracks
                WHERE is_active = true
                ORDER BY id
                """, (rs, i) -> {
            Map<String, Object> row = new LinkedHashMap<>();
            long id = rs.getLong("id");
            String filePath = rs.getString("file_path");
            row.put("id", id);
            row.put("title", rs.getString("title"));
            row.put("artist", rs.getString("artist"));
            row.put("file_path", filePath);
            row.put("file_format", rs.getString("file_format"));
            row.put("duration", Db.intOrNull(rs, "duration"));
            // bigint: старый сервер отдавал его строкой, приложение читает file_size как String
            row.put("file_size", rs.getString("file_size"));
            row.put("is_active", rs.getBoolean("is_active"));
            row.put("play_count", Db.intOrNull(rs, "play_count"));
            var created = Db.instant(rs, "created_at");
            row.put("created_at", created == null ? null : JsonConfig.iso(created));
            row.put("url", baseUrl + filePath);
            row.put("streamUrl", baseUrl + "/guest-tracks/" + id + "/stream");
            return row;
        });
        log.debug("Активных гостевых треков: {}", rows.size());
        return rows;
    }

    @Operation(summary = "Потоковая передача гостевого трека по названию")
    @GetMapping("/by-title/stream")
    public void streamByTitle(HttpServletRequest req, HttpServletResponse res) throws IOException {
        String title = singleParam(req, "title");
        if (title == null || JsStrings.trim(title).isEmpty()) {
            throw HttpError.badRequest("Не указано название трека");
        }

        List<Map<String, Object>> found = jdbc.queryForList("""
                SELECT id, file_path, file_format, title
                FROM guest_tracks
                WHERE LOWER(TRIM(title)) = LOWER(TRIM(?)) AND is_active = true
                LIMIT 1
                """, title);
        if (found.isEmpty()) {
            throw HttpError.notFound("Трек не найден");
        }
        streamDbTrack(req, res, found.get(0));
    }

    @Operation(summary = "Потоковая передача трека из папки NFC по названию")
    @GetMapping("/nfc/stream")
    public void streamNfc(HttpServletRequest req, HttpServletResponse res) throws IOException {
        String title = singleParam(req, "title");
        if (title == null || JsStrings.trim(title).isEmpty()) {
            throw HttpError.badRequest("Не указано название трека");
        }

        Path nfcDir = config.storageRoot().resolve("nfc").normalize();
        if (!Files.exists(nfcDir)) {
            throw HttpError.notFound("Папка NFC не найдена");
        }

        List<String> files;
        try (Stream<Path> listing = Files.list(nfcDir)) {
            files = listing.map(p -> p.getFileName().toString()).sorted().toList();
        }

        String cleanedTitle = cleanNfcTitle(title);
        String foundFile = findNfcFile(files, cleanedTitle);
        if (foundFile == null) {
            Map<String, Object> extra = new LinkedHashMap<>();
            extra.put("requestedTitle", cleanedTitle);
            extra.put("originalTitle", title);
            extra.put("availableFiles", files);
            throw new HttpError(404, "Трек не найден в папке NFC", extra);
        }

        Path absPath = nfcDir.resolve(foundFile);
        if (!Files.isRegularFile(absPath)) {
            throw HttpError.notFound("Файл не найден");
        }
        String contentType = MimeTypes.lookup(extname(foundFile).toLowerCase(Locale.ROOT)).orElse("audio/mpeg");
        RangeStreaming.stream(req, res, absPath, contentType, RangeStreaming.Mode.GUEST);
    }

    @Operation(summary = "Потоковая передача гостевого трека")
    @GetMapping("/{id}/stream")
    public void streamById(@PathVariable("id") String rawId, HttpServletRequest req, HttpServletResponse res)
            throws IOException {
        Long id = JsNumbers.positiveInt(rawId);
        List<Map<String, Object>> found = id == null ? List.of() : jdbc.queryForList("""
                SELECT id, file_path, file_format
                FROM guest_tracks
                WHERE id = ? AND is_active = true
                LIMIT 1
                """, id);
        if (found.isEmpty()) {
            throw HttpError.notFound("Трек не найден");
        }
        streamDbTrack(req, res, found.get(0));
    }

    private void streamDbTrack(HttpServletRequest req, HttpServletResponse res, Map<String, Object> track)
            throws IOException {
        String dbPath = (String) track.get("file_path");
        // Убираем /storage из начала пути, если есть
        String relativePath = dbPath.startsWith("/storage/") ? dbPath.replaceFirst("/storage/", "")
                : dbPath.startsWith("/") ? dbPath.substring(1)
                : dbPath;
        Path absPath = config.storageRoot().resolve(relativePath).normalize();

        if (!Files.isRegularFile(absPath)) {
            log.error("Файл гостевого трека не найден: {} (в базе: {})", absPath, dbPath);
            throw HttpError.notFound("Файл не найден");
        }

        String format = (String) track.get("file_format");
        String contentType = MimeTypes.lookup(format != null && !format.isEmpty() ? format : extname(absPath.toString()))
                .orElse("audio/mpeg");
        RangeStreaming.stream(req, res, absPath, contentType, RangeStreaming.Mode.GUEST);
    }

    /** ?title=... ровно один раз (повтор параметра в Express давал массив и 400) */
    private static String singleParam(HttpServletRequest req, String name) {
        String[] values = req.getParameterValues(name);
        return values != null && values.length == 1 ? values[0] : null;
    }

    /** Убирает пробелы, управляющие символы в начале и префикс "en" (так NFC-метки кодируют язык) */
    static String cleanNfcTitle(String title) {
        String cleaned = JsStrings.trim(title);
        int start = 0;
        while (start < cleaned.length() && cleaned.charAt(start) < 32) start++;
        cleaned = JsStrings.trim(cleaned.substring(start));
        if (cleaned.length() >= 2 && cleaned.substring(0, 2).toLowerCase(Locale.ROOT).equals("en")) {
            cleaned = JsStrings.trim(cleaned.substring(2));
        }
        return cleaned;
    }

    /** Поиск файла в папке NFC по тем же правилам, что в старом сервере (первое совпадение по алфавиту) */
    static String findNfcFile(List<String> files, String cleanedTitle) {
        String titleLower = cleanedTitle.toLowerCase(Locale.ROOT);
        for (String file : files) {
            String nameLower = nameWithoutExt(file).toLowerCase(Locale.ROOT);
            String fileLower = file.toLowerCase(Locale.ROOT);

            if (nameLower.equals(titleLower) || fileLower.equals(titleLower)) return file;
            for (String ext : AUDIO_EXTENSIONS) {
                if (fileLower.equals(titleLower + ext)) return file;
            }
            if (nameLower.startsWith(titleLower) || titleLower.startsWith(nameLower)) return file;
            if (nameLower.startsWith("en")) {
                String withoutEn = nameLower.substring(2);
                if (withoutEn.equals(titleLower) || withoutEn.startsWith(titleLower) || titleLower.startsWith(withoutEn)) {
                    return file;
                }
            }
            if (titleLower.startsWith("en")) {
                String titleWithoutEn = titleLower.substring(2);
                if (nameLower.equals(titleWithoutEn) || nameLower.startsWith(titleWithoutEn)
                        || titleWithoutEn.startsWith(nameLower)) {
                    return file;
                }
            }
        }
        return null;
    }

    /** path.parse(file).name */
    static String nameWithoutExt(String file) {
        int dot = file.lastIndexOf('.');
        return dot <= 0 ? file : file.substring(0, dot);
    }

    static String extname(String path) {
        String base = path.substring(Math.max(path.lastIndexOf('/'), path.lastIndexOf('\\')) + 1);
        int dot = base.lastIndexOf('.');
        return dot <= 0 ? "" : base.substring(dot);
    }
}
