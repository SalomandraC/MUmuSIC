package ru.mumusic.api.tracks;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.multipart.MultipartHttpServletRequest;
import ru.mumusic.api.common.HttpError;
import ru.mumusic.api.common.JsNumbers;
import ru.mumusic.api.common.ValidationIssues;
import ru.mumusic.api.config.AppConfig;
import ru.mumusic.api.security.AuthUser;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/** Личные треки пользователя: загрузка, список, получение, удаление */
@RestController
@RequestMapping("/tracks")
@Tag(name = "Tracks", description = "Личные треки")
public class TracksController {

    private static final Logger log = LoggerFactory.getLogger(TracksController.class);
    private static final Set<String> ALLOWED = Set.of(".mp3", ".wav", ".m4a", ".flac");

    private final TracksService service;
    private final AppConfig config;

    public TracksController(TracksService service, AppConfig config) {
        this.service = service;
        this.config = config;
    }

    @Operation(summary = "Загрузить трек (multipart: file, title, artist, album, duration, notes, is_public)",
            security = @SecurityRequirement(name = "bearerAuth"))
    @PostMapping({"", "/"})
    public ResponseEntity<Object> create(@AuthenticationPrincipal AuthUser user, HttpServletRequest req) throws IOException {
        long userId = requireUser(user);

        MultipartFile file = req instanceof MultipartHttpServletRequest multipart ? multipart.getFile("file") : null;
        if (file == null) {
            throw HttpError.badRequest("Файл не загружен");
        }

        String originalName = file.getOriginalFilename() == null ? "" : file.getOriginalFilename();
        String ext = extname(originalName).toLowerCase(Locale.ROOT);
        if (!ALLOWED.contains(ext)) {
            throw HttpError.badRequest("Недопустимое расширение файла. Разрешены: mp3, wav, m4a, flac");
        }

        String rawTitle = req.getParameter("title");
        String title = rawTitle != null && !rawTitle.isEmpty() ? rawTitle : basename(originalName, ext);
        String rawDuration = req.getParameter("duration");
        Integer duration = null;
        if (rawDuration != null && !rawDuration.isEmpty()) {
            double n = JsNumbers.toNumber(rawDuration);
            if (Double.isNaN(n) || Double.isInfinite(n)) {
                throw invalid(List.of("duration"), "Ожидалось число");
            }
            duration = (int) Math.round(n);
        }
        if (title.isEmpty()) {
            throw invalid(List.of("title"), "Название не может быть пустым");
        }

        TrackRepository.NewTrack data = new TrackRepository.NewTrack(
                title,
                emptyToNull(req.getParameter("artist")),
                emptyToNull(req.getParameter("album")),
                duration == null || duration == 0 ? null : duration,
                emptyToNull(req.getParameter("notes")),
                "true".equals(req.getParameter("is_public"))
        );

        // Сохраняем в users/{userId}/, папка создаётся автоматически
        Path accountDir = config.storageRoot().resolve("users").resolve(Long.toString(userId));
        Files.createDirectories(accountDir);
        String sanitized = sanitize(originalName);
        Path target = accountDir.resolve(sanitized);
        try (InputStream in = file.getInputStream()) {
            Files.copy(in, target, StandardCopyOption.REPLACE_EXISTING);
        }
        long size = Files.size(target);
        String relativePath = "users/" + userId + "/" + sanitized;

        Map<String, Object> track = service.create(userId, data, relativePath, ext.substring(1), size);
        return ResponseEntity.status(201).body(track);
    }

    @Operation(summary = "Мои треки", security = @SecurityRequirement(name = "bearerAuth"))
    @GetMapping({"", "/"})
    public Map<String, Object> list(@AuthenticationPrincipal AuthUser user) {
        long userId = requireUser(user);
        List<Map<String, Object>> tracks = service.userTracks(userId);
        log.debug("getUserTracks: {} треков у пользователя {}", tracks.size(), userId);
        return Map.of("tracks", tracks);
    }

    @Operation(summary = "Трек по id (свой или публичный)", security = @SecurityRequirement(name = "bearerAuth"))
    @GetMapping("/{id}")
    public Map<String, Object> get(@AuthenticationPrincipal AuthUser user, @PathVariable("id") String rawId) {
        long userId = requireUser(user);
        Long id = JsNumbers.positiveInt(rawId);
        Map<String, Object> track = id == null ? null : service.byId(id, userId);
        if (track == null) throw HttpError.notFound("Трек не найден");
        return track;
    }

    @Operation(summary = "Удалить свой трек", security = @SecurityRequirement(name = "bearerAuth"))
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal AuthUser user, @PathVariable("id") String rawId) {
        long userId = requireUser(user);
        Long id = JsNumbers.positiveInt(rawId);
        if (id == null || !service.delete(id, userId)) throw HttpError.notFound("Трек не найден");
        return ResponseEntity.noContent().build();
    }

    static long requireUser(AuthUser user) {
        if (user == null || user.id() == 0) throw HttpError.unauthorized("Необходима аутентификация");
        return user.id();
    }

    private static HttpError invalid(List<Object> path, String message) {
        return new HttpError(400, "Неверные данные", Map.of("details", List.of(ValidationIssues.issue(path, message))));
    }

    /** path.extname: расширение последнего сегмента, у ".hidden" его нет */
    static String extname(String name) {
        String base = name.substring(Math.max(name.lastIndexOf('/'), name.lastIndexOf('\\')) + 1);
        int dot = base.lastIndexOf('.');
        return dot <= 0 ? "" : base.substring(dot);
    }

    /** path.basename(name, ext): ext отрезается, только если имя на него оканчивается */
    static String basename(String name, String ext) {
        String base = name.substring(Math.max(name.lastIndexOf('/'), name.lastIndexOf('\\')) + 1);
        return !ext.isEmpty() && base.endsWith(ext) && !base.equals(ext) ? base.substring(0, base.length() - ext.length()) : base;
    }

    /** Как replace(/[^a-zA-Z0-9._ -]/g, '_') */
    static String sanitize(String name) {
        StringBuilder sb = new StringBuilder(name.length());
        for (char c : name.toCharArray()) {
            boolean ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
                    || c == '.' || c == '_' || c == ' ' || c == '-';
            sb.append(ok ? c : '_');
        }
        return sb.toString();
    }

    private static String emptyToNull(String value) {
        return value == null || value.isEmpty() ? null : value;
    }
}
