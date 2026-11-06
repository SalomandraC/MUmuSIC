package ru.mumusic.api.storage;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import ru.mumusic.api.common.GlobalExceptionHandler;
import ru.mumusic.api.config.AppConfig;
import ru.mumusic.api.security.TokenService;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;

/**
 * /storage/** — раздача аудиофайлов (замена express.static + storageGuard).
 * Личные файлы users/{id}/... доступны только владельцу; на чужие и несуществующие
 * личные файлы ответ одинаковый (404), чтобы по нему нельзя было перебирать id.
 * Range-запросы (перемотка) обрабатывает Spring: 206 Partial Content / 416.
 */
@RestController
@Tag(name = "Storage", description = "Файлы треков")
public class StorageController {

    private final AppConfig config;
    private final TokenService tokens;

    public StorageController(AppConfig config, TokenService tokens) {
        this.config = config;
        this.tokens = tokens;
    }

    @Operation(summary = "Файл из хранилища (Range поддерживается)")
    @GetMapping({"/storage", "/storage/**"})
    public ResponseEntity<?> file(HttpServletRequest req) throws IOException {
        String uri = req.getRequestURI();
        String raw = uri.length() > "/storage".length() ? uri.substring("/storage".length()) : "/";

        String relPath = StorageAccess.normalizePath(raw);
        if (relPath == null) {
            return ResponseEntity.status(404).body(Map.of("error", "Файл не найден"));
        }

        StorageAccess.Access access = StorageAccess.resolve(relPath, readCredentials(req));
        if (access == StorageAccess.Access.DENY) {
            return ResponseEntity.status(404).body(Map.of("error", "Файл не найден"));
        }

        Path root = config.storageRoot();
        Path file = root.resolve(relPath).normalize();
        if (!file.startsWith(root) || !Files.isRegularFile(file)) {
            return ResponseEntity.status(404).body(GlobalExceptionHandler.notFoundBody(req));
        }

        long size = Files.size(file);
        long modified = Files.getLastModifiedTime(file).toMillis();
        MediaType type = MimeTypes.lookup(file.getFileName().toString())
                .map(MediaType::parseMediaType)
                .orElse(MediaType.APPLICATION_OCTET_STREAM);

        Resource resource = new FileSystemResource(file);
        return ResponseEntity.ok()
                .contentType(type)
                .header(HttpHeaders.ACCEPT_RANGES, "bytes")
                .header(HttpHeaders.CACHE_CONTROL,
                        access == StorageAccess.Access.PRIVATE ? "private, max-age=3600" : "public, max-age=3600")
                .eTag("W/\"" + Long.toHexString(size) + "-" + Long.toHexString(modified) + "\"")
                .lastModified(modified)
                .body(resource);
    }

    private StorageAccess.Credentials readCredentials(HttpServletRequest req) {
        Long userId = null;
        Long mediaSub = null;
        String mediaPath = null;

        String header = req.getHeader("Authorization");
        if (header != null) {
            String[] parts = header.split(" ", -1);
            if (parts.length > 1 && parts[0].equals("Bearer") && !parts[1].isEmpty()) {
                try {
                    userId = tokens.verifyAccessToken(parts[1]).sub();
                } catch (TokenService.InvalidTokenException ignored) {
                    // Невалидный заголовок не даёт доступа, но и не мешает проверить ?token
                }
            }
        }

        String[] tokenParams = req.getParameterValues("token");
        if (tokenParams != null && tokenParams.length == 1 && !tokenParams[0].isEmpty()) {
            try {
                TokenService.TokenPayload media = tokens.verifyMediaToken(tokenParams[0]);
                mediaSub = media.sub();
                mediaPath = media.path();
            } catch (TokenService.InvalidTokenException ignored) {
                // Просроченная или поддельная ссылка
            }
        }
        return new StorageAccess.Credentials(userId, mediaSub, mediaPath);
    }
}
