package ru.mumusic.api.topchart;

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
import ru.mumusic.api.common.JsonConfig;
import ru.mumusic.api.config.AppConfig;
import ru.mumusic.api.storage.RangeStreaming;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Топ-10 гостевых треков по прослушиваниям и их стрим (порт top-chart.*) */
@RestController
@RequestMapping("/top-charts")
@Tag(name = "TopCharts", description = "Топ-чарт")
public class TopChartController {

    private static final Logger log = LoggerFactory.getLogger(TopChartController.class);

    private final JdbcTemplate jdbc;
    private final AppConfig config;

    public TopChartController(JdbcTemplate jdbc, AppConfig config) {
        this.jdbc = jdbc;
        this.config = config;
    }

    record ChartRow(long id, String title, String artist, String filePath, String fileFormat, int duration,
                    String fileSize, boolean isActive, int playCount, Instant createdAt) {}

    private List<ChartRow> activeTop() {
        return jdbc.query("""
                SELECT * FROM public.guest_tracks
                WHERE is_active = true
                ORDER BY play_count DESC
                LIMIT 10
                """, (rs, i) -> {
            Integer duration = Db.intOrNull(rs, "duration");
            Integer plays = Db.intOrNull(rs, "play_count");
            String size = rs.getString("file_size");
            Instant created = Db.instant(rs, "created_at");
            return new ChartRow(
                    rs.getLong("id"),
                    orEmpty(rs.getString("title")),
                    orEmpty(rs.getString("artist")),
                    orEmpty(rs.getString("file_path")),
                    orEmpty(rs.getString("file_format")),
                    duration == null ? 0 : duration,
                    size == null ? "0" : size,
                    rs.getBoolean("is_active"),
                    plays == null ? 0 : plays,
                    created == null ? Instant.now() : created);
        });
    }

    @Operation(summary = "Топ-10 активных гостевых треков")
    @GetMapping({"", "/"})
    public List<Map<String, Object>> list(HttpServletRequest req) {
        String base = BaseUrl.of(req);
        return activeTop().stream().map(chart -> {
            String normalized = normalizeStoragePath(chart.filePath().replace('\\', '/'));
            Map<String, Object> out = new LinkedHashMap<>();
            out.put("id", chart.id());
            out.put("title", chart.title());
            out.put("artist", chart.artist());
            out.put("file_path", chart.filePath());
            out.put("file_format", chart.fileFormat());
            out.put("duration", chart.duration());
            out.put("file_size", chart.fileSize());
            out.put("is_active", chart.isActive());
            out.put("play_count", chart.playCount());
            out.put("created_at", JsonConfig.iso(chart.createdAt()));
            out.put("url", normalized.isEmpty() ? "" : base + "/storage/" + normalized);
            out.put("streamUrl", chart.id() != 0 ? base + "/top-charts/" + chart.id() + "/stream" : "");
            return out;
        }).toList();
    }

    @Operation(summary = "Стрим трека из топ-чарта")
    @GetMapping("/{id}/stream")
    public void stream(@PathVariable("id") String rawId, HttpServletRequest req, HttpServletResponse res)
            throws IOException {
        double n = JsNumbers.toNumber(rawId);
        if (Double.isNaN(n) || n == 0) {
            throw HttpError.badRequest("Неверный ID трека");
        }

        ChartRow track = activeTop().stream()
                .filter(t -> t.id() == n)
                .findFirst()
                .orElse(null);
        if (track == null || track.filePath().isEmpty()) {
            throw HttpError.notFound("Трек не найден");
        }

        String relPath = normalizeStoragePath(track.filePath().replace('\\', '/'));
        Path file = config.storageRoot().resolve(relPath).normalize();
        if (!Files.isRegularFile(file)) {
            log.error("Файл трека из топ-чарта не найден: {}", file);
            throw HttpError.notFound("Файл не найден");
        }
        RangeStreaming.stream(req, res, file, "audio/mpeg", RangeStreaming.Mode.TOP_CHART);
    }

    /** Убирает "/storage/" или "/" в начале пути из базы */
    static String normalizeStoragePath(String p) {
        if (p == null || p.isEmpty()) return "";
        return p.replaceFirst("^/(storage)?/?", "");
    }

    private static String orEmpty(String value) {
        return value == null ? "" : value;
    }
}
