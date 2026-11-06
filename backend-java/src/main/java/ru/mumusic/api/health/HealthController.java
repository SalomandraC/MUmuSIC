package ru.mumusic.api.health;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import ru.mumusic.api.common.JsonConfig;
import ru.mumusic.api.config.AppConfig;

import java.nio.file.Files;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

@RestController
@Tag(name = "Health", description = "Проверки для Docker и балансировщика")
public class HealthController {

    private static final long READY_TIMEOUT_MS = 2000;

    private final JdbcTemplate jdbc;
    private final AppConfig config;
    private final ShutdownState shutdown;

    public HealthController(JdbcTemplate jdbc, AppConfig config, ShutdownState shutdown) {
        this.jdbc = jdbc;
        this.config = config;
        this.shutdown = shutdown;
    }

    /** Процесс жив. Ничего внешнего не проверяет, чтобы Docker не перезапускал контейнер из-за базы */
    @Operation(summary = "Процесс жив")
    @GetMapping("/health")
    public Map<String, Object> health() {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("status", "ok");
        out.put("timestamp", JsonConfig.iso(Instant.now()));
        return out;
    }

    /** Готов принимать трафик: есть база и хранилище */
    @Operation(summary = "Готов принимать трафик (база и хранилище доступны)")
    @GetMapping("/ready")
    public ResponseEntity<Map<String, Object>> ready() {
        if (shutdown.isShuttingDown()) {
            return ResponseEntity.status(503).body(Map.of("status", "shutting_down"));
        }

        Map<String, Object> checks = new LinkedHashMap<>();
        try {
            CompletableFuture.supplyAsync(() -> jdbc.queryForObject("SELECT 1", Integer.class))
                    .get(READY_TIMEOUT_MS, TimeUnit.MILLISECONDS);
            checks.put("database", "ok");
        } catch (TimeoutException e) {
            checks.put("database", "timeout " + READY_TIMEOUT_MS + "ms");
        } catch (Exception e) {
            Throwable cause = e.getCause() != null ? e.getCause() : e;
            checks.put("database", String.valueOf(cause.getMessage()));
        }
        checks.put("storage", Files.exists(config.storageRoot()) ? "ok" : "not found");

        boolean ready = checks.values().stream().allMatch("ok"::equals);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("status", ready ? "ready" : "not_ready");
        out.put("checks", checks);
        return ResponseEntity.status(ready ? 200 : 503).body(out);
    }
}
